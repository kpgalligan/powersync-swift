import Foundation
import OSLog

actor BucketStorage {
    private let db: PowerSyncDatabaseProtocol
    private let logger: Logger
    private let compactionManager: CompactionManager
    private let bucketStateManager: BucketStateManager
    private var hasCompletedSync: Bool
    private let sharedPendingDeletes: SharedPendingDeletesActor

    private enum Constants {
        static let maxOpId = "9223372036854775807"
    }

    init(db: PowerSyncDatabaseProtocol) {
        self.db = db
        self.logger = Logger(subsystem: "com.powersync.bucket", category: "BucketStorage")
        self.hasCompletedSync = false
        self.sharedPendingDeletes = SharedPendingDeletesActor()

        self.compactionManager = CompactionManager(
            db: db,
            logger: logger,
            pendingBucketDeletes: sharedPendingDeletes
        )

        self.bucketStateManager = BucketStateManager(
            db: db,
            logger: logger,
            pendingBucketDeletes: sharedPendingDeletes
        )
    }

    func getMaxOpId() -> String {
        Constants.maxOpId
    }

    func getClientId() async throws -> String {
        guard let id = try await db.getOptional(
            "SELECT powersync_client_id() as client_id",
            mapper: { $0.getString(index: 0)! }
        ) else {
            throw BucketStorageError.clientIdNotFound
        }
        return id
    }

    func nextCrudItem() async throws -> CrudEntry? {
        try await db.getOptional(
            "SELECT id, tx_id, data FROM \(InternalTable.crud) ORDER BY id ASC LIMIT 1"
        ) { cursor in
            CrudEntry.fromRow(CrudRow(
                id: cursor.getString(index: 0)!,
                txId: cursor.getString(index: 1).flatMap { Int($0) },
                data: cursor.getString(index: 2)!
            ))
        }
    }

    func hasCrud() async throws -> Bool {
        guard let res = try await db.getOptional(
            "SELECT 1 FROM ps_crud LIMIT 1",
            mapper: { $0.getLong(index: 0)! }
        ) else {
            return false
        }
        return res == 1
    }

    func updateLocalTarget(checkpointCallback: @escaping () async throws -> String) async throws -> Bool {
        guard try await db.getOptional(
            "SELECT target_op FROM \(InternalTable.buckets) WHERE name = '$local' AND target_op = ?",
            [Constants.maxOpId],
            mapper: { $0.getLong(index: 0)! }
        ) != nil else {
            return false
        }

        // Get sequence before checkpoint
        guard let seqBefore = try await db.getOptional(
            "SELECT seq FROM sqlite_sequence WHERE name = '\(InternalTable.crud)'",
            mapper: { $0.getLong(index: 0)! }
        ) else {
            return false
        }

        let opId = try await checkpointCallback()

        logger.info("Updating target to checkpoint \(opId)")

        return try await db.writeTransaction { [weak self] transaction in
            guard let self = self else { return false }

            if try await hasCrud() {
                logger.warning("ps crud is not empty")
                return false
            }

            guard let seqAfter = try await db.getOptional(
                "SELECT seq FROM sqlite_sequence WHERE name = '\(InternalTable.crud)'",
                mapper: { $0.getLong(index: 0)! }
            ) else {
                throw BucketStorageError.sqliteSequenceEmpty
            }

            if seqAfter != seqBefore {
                logger.debug("seqAfter != seqBefore seqAfter: \(seqAfter) seqBefore: \(seqBefore)")
                return false
            }

            _ = try await transaction.execute(
                "UPDATE \(InternalTable.buckets) SET target_op = CAST(? as INTEGER) WHERE name='$local'",
                [opId]
            )

            return true
        }
    }

    func saveSyncData(_ syncDataBatch: SyncDataBatch) async throws {
        let jsonString = try JSONEncoder().encode(syncDataBatch)
        _ = try await db.execute(
            "INSERT INTO powersync_operations(op, data) VALUES(?, ?)",
            ["save", String(data: jsonString, encoding: .utf8)!]
        )

        await compactionManager.incrementCounter(syncDataBatch.buckets.reduce(0) { $0 + $1.data.count })
    }

    func getBucketStates() async throws -> [BucketState] {
        try await bucketStateManager.getBucketStates()
    }

    func removeBuckets(_ bucketsToDelete: [String]) async throws {
        try await bucketStateManager.removeBuckets(bucketsToDelete)
    }

    func hasCompletedSync() async throws -> Bool {
        if hasCompletedSync {
            return true
        }

        if let _ = try await db.getOptional(
            "SELECT powersync_last_synced_at()",
            mapper: { $0.getString(index: 0)! }
        ) {
            hasCompletedSync = true
            return true
        }

        return false
    }

    func syncLocalDatabase(targetCheckpoint: Checkpoint) async throws -> SyncLocalDatabaseResult {
        var result = try await bucketStateManager.validateChecksums(targetCheckpoint)

        if !result.checkpointValid {
            logger.warning("Checksums failed for \(String(describing: result.checkpointFailures))")
            if let failures = result.checkpointFailures {
                for bucketName in failures {
                    try await bucketStateManager.deleteBucket(bucketName)
                }
            }
            result.ready = false
            return result
        }

        try await bucketStateManager.updateBucketsWithCheckpoint(targetCheckpoint)

        let valid = try await updateObjectsFromBuckets()

        if !valid {
            return SyncLocalDatabaseResult(
                ready: false,
                checkpointValid: true
            )
        }

        try await compactionManager.forceCompact()

        return SyncLocalDatabaseResult(ready: true)
    }

    private func updateObjectsFromBuckets() async throws -> Bool {
        try await db.writeTransaction { transaction in
            _ = try await db.execute(
                "INSERT INTO powersync_operations(op, data) VALUES(?, ?)",
                ["sync_local", ""]
            )

            let res = try await db.get("select last_insert_rowid()", mapper: { $0.getLong(index: 0)! })

            return res == 1
        }
    }

    func setTargetCheckpoint(_ checkpoint: Checkpoint) {
        // No-op for now
    }
}

// MARK: - Supporting Types and Errors

enum BucketStorageError: Error {
    case clientIdNotFound
    case sqliteSequenceEmpty
}
