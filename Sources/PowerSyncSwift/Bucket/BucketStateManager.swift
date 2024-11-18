import Foundation
import OSLog

class BucketStateManager {
    private let db: PowerSyncDatabaseProtocol
    private let logger: Logger
    private var tableNames: Set<String>
    private let pendingBucketDeletes: SharedPendingDeletesActor
    
    init(db: PowerSyncDatabaseProtocol, logger: Logger, pendingBucketDeletes: SharedPendingDeletesActor) {
        self.db = db
        self.logger = logger
        self.tableNames = []
        self.pendingBucketDeletes = pendingBucketDeletes
    }
    
    func getBucketStates() async throws -> [BucketState] {
        try await db.getAll(
            "SELECT name AS bucket, CAST(last_op AS TEXT) AS op_id FROM \(InternalTable.buckets.rawValue) WHERE pending_delete = 0"
        ) { cursor in
            BucketState(
                bucket: cursor.getString(index: 0)!,
                opId: cursor.getString(index: 1)!
            )
        }
    }
    
    func removeBuckets(_ bucketsToDelete: [String]) async throws {
        for bucketName in bucketsToDelete {
            try await deleteBucket(bucketName)
        }
    }
    
    func deleteBucket(_ bucketName: String) async throws {
        _ = try await db.execute(
            "INSERT INTO powersync_operations(op, data) VALUES(?, ?)",
            ["delete_bucket", bucketName]
        )
        
        logger.debug("Done deleting bucket")
        await pendingBucketDeletes.setPendingBucketDeletes(true)
    }
    
    func updateBucketsWithCheckpoint(_ targetCheckpoint: Checkpoint) async throws {
        let bucketNames = targetCheckpoint.checksums.map { $0.bucket }
        
        try await db.writeTransaction { transaction in
            _ = try await transaction.execute(
                "UPDATE ps_buckets SET last_op = ? WHERE name IN (SELECT json_each.value FROM json_each(?))",
                [targetCheckpoint.lastOpId, String(data: try JSONEncoder().encode(bucketNames), encoding: .utf8)!]
            )
            
            if let writeCheckpoint = targetCheckpoint.writeCheckpoint {
                _ = try await transaction.execute(
                    "UPDATE ps_buckets SET last_op = ? WHERE name = '$local'",
                    [writeCheckpoint]
                )
            }
        }
    }
    
    func validateChecksums(_ checkpoint: Checkpoint) async throws -> SyncLocalDatabaseResult {
        guard let res = try await db.getOptional(
            "SELECT powersync_validate_checkpoint(?) AS result",
            [String(data: try JSONEncoder().encode(checkpoint), encoding: .utf8)!],
            mapper: { $0.getString(index: 0)! }
        ) else {
            return SyncLocalDatabaseResult(
                ready: false,
                checkpointValid: false
            )
        }
        
        return try JSONDecoder().decode(SyncLocalDatabaseResult.self, from: res.data(using: .utf8)!)
    }
}
