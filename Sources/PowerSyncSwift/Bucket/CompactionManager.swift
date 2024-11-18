import Foundation
import OSLog

actor CompactionManager {
    private let db: PowerSyncDatabaseProtocol
    private let logger: Logger
    private var compactCounter: Int
    private let pendingBucketDeletes: SharedPendingDeletesActor
    
    private enum Constants {
        static let compactOperationInterval = 1_000
    }
    
    init(db: PowerSyncDatabaseProtocol, logger: Logger, pendingBucketDeletes: SharedPendingDeletesActor) {
        self.db = db
        self.logger = logger
        self.pendingBucketDeletes = pendingBucketDeletes
        self.compactCounter = Constants.compactOperationInterval
    }
    
    func incrementCounter(_ amount: Int) {
        compactCounter += amount
    }
    
    func resetCounter() {
        compactCounter = Constants.compactOperationInterval
    }
    
    func forceCompact() async throws {
        resetCounter()
        await pendingBucketDeletes.setPendingBucketDeletes(true)
        try await autoCompact()
    }
    
    func autoCompact() async throws {
        // 1. Delete buckets
        try await deletePendingBuckets()
        
        // 2. Clear REMOVE operations, only keeping PUT ones
        try await clearRemoveOps()
    }
    
    private func deletePendingBuckets() async throws {
        guard await pendingBucketDeletes.getPendingBucketDeletes() else { return }
        
        // TODO: Fix transactions and change this back
//        try await db.writeTransaction { transaction in
            _ = try await db.execute(
                "INSERT INTO powersync_operations(op, data) VALUES (?, ?)",
                ["delete_pending_buckets", ""]
            )
            
            // Executed once after start-up, and again when there are pending deletes.
            await pendingBucketDeletes.setPendingBucketDeletes(false)
//        }
    }
    
    private func clearRemoveOps() async throws {
        guard compactCounter >= Constants.compactOperationInterval else { return }
        
        // TODO: Fix transactions and change this back
//        _ = try await db.writeTransaction { transaction in
            _ = try await db.execute(
                "INSERT INTO powersync_operations(op, data) VALUES (?, ?)",
                ["clear_remove_ops", ""]
            )
//        }
        
        compactCounter = 0
    }
}
