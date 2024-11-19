import Foundation
import Combine
import os

class SyncStateManager {
    enum SyncError: Error {
        case invalidCheckpoint
        case inconsistentState
        case missingTargetCheckpoint
        case storageError
    }
    
    private(set) var status: SyncStatus
    private var state: SyncStreamState
    private let logger: Logger
    
    struct SyncStreamState {
        var targetCheckpoint: Checkpoint?
        var validatedCheckpoint: Checkpoint?
        var appliedCheckpoint: Checkpoint?
        var bucketSet: Set<String>
        var retry: Bool
        
        init(
            targetCheckpoint: Checkpoint? = nil,
            validatedCheckpoint: Checkpoint? = nil,
            appliedCheckpoint: Checkpoint? = nil,
            bucketSet: Set<String> = [],
            retry: Bool = false
        ) {
            self.targetCheckpoint = targetCheckpoint
            self.validatedCheckpoint = validatedCheckpoint
            self.appliedCheckpoint = appliedCheckpoint
            self.bucketSet = bucketSet
            self.retry = retry
        }
    }
    
    init(logger: Logger) {
        self.status = SyncStatus()
        self.state = SyncStreamState()
        self.logger = logger
    }
    
    func handleMessage(_ message: StreamMessageParser.Message, storage: BucketStorage) async throws {
        switch message {
        case .checkpoint(let checkpoint):
            try await handleCheckpoint(checkpoint, storage: storage)
        case .checkpointComplete:
            try await handleCheckpointComplete(storage: storage)
        case .checkpointDiff(let diff):
            try await handleCheckpointDiff(diff, storage: storage)
        case .syncData(let bucket):
            try await handleSyncData(bucket, storage: storage)
        case .keepAlive(let tokenExpiresIn):
            try await handleKeepAlive(tokenExpiresIn: tokenExpiresIn)
        }
    }
    
    private func handleCheckpoint(_ checkpoint: Checkpoint, storage: BucketStorage) async throws {
        state.targetCheckpoint = checkpoint
        let bucketsToDelete = state.bucketSet.subtracting(checkpoint.checksums.map { $0.bucket })
        let newBuckets = Set(checkpoint.checksums.map { $0.bucket })
        
        if !bucketsToDelete.isEmpty {
            logger.info("Removing buckets: \(bucketsToDelete.joined(separator: ", "))")
        }
        
        state.bucketSet = newBuckets
        
        do {
            try await storage.removeBuckets(Array(bucketsToDelete))
            await storage.setTargetCheckpoint(checkpoint)
            
            status.update(
                downloading: true,
                clearDownloadError: true
            )
        } catch {
            logger.error("Error handling checkpoint: \(error.localizedDescription)")
            status.update(
                downloading: false,
                downloadError: error
            )
            throw SyncError.storageError
        }
    }
    
    private func handleCheckpointComplete(storage: BucketStorage) async throws {
        guard let targetCheckpoint = state.targetCheckpoint else {
            let error = SyncError.missingTargetCheckpoint
            status.update(downloadError: error)
            throw error
        }
        
        do {
            let result = try await storage.syncLocalDatabase(targetCheckpoint: targetCheckpoint)
            
            if !result.checkpointValid {
                logger.warning("Checkpoint validation failed, triggering retry")
                state.retry = true
                
                status.update(
                    downloading: false,
                    downloadError: (SyncError.invalidCheckpoint)
                )
                
                throw SyncError.invalidCheckpoint
            }
            
            if !result.ready {
                logger.info("Waiting for more data for consistent checkpoint")
                return
            }
            
            state.appliedCheckpoint = targetCheckpoint
            state.validatedCheckpoint = targetCheckpoint
            
            status.update(
                downloading: false,
                lastSyncedAt: Date(),
                clearDownloadError: true
            )
            
            logger.info("Validated checkpoint: \(targetCheckpoint)")
        } catch {
            logger.error("Error handling checkpoint complete: \(error.localizedDescription)")
            
            status.update(
                downloading: false,
                downloadError: error
            )
            
            throw error
        }
    }
    
    private func handleCheckpointDiff(_ diff: StreamingSyncCheckpointDiff, storage: BucketStorage) async throws {
        guard let currentCheckpoint = state.targetCheckpoint else {
            let error = SyncError.inconsistentState
            status.update(downloadError: error)
            throw error
        }
        
        // Create new bucket checksums map
        var newBuckets = Dictionary(
            uniqueKeysWithValues: currentCheckpoint.checksums.map { ($0.bucket, $0) }
        )
        
        // Update with new checksums
        for checksum in diff.updatedBuckets {
            newBuckets[checksum.bucket] = checksum
        }
        
        // Remove specified buckets
        for bucket in diff.removedBuckets {
            newBuckets.removeValue(forKey: bucket)
        }
        
        let newCheckpoint = Checkpoint(
            lastOpId: diff.lastOpId,
            checksums: Array(newBuckets.values),
            writeCheckpoint: diff.writeCheckpoint
        )
        
        state.targetCheckpoint = newCheckpoint
        state.bucketSet = Set(newBuckets.keys)
        
        if !diff.removedBuckets.isEmpty {
            logger.debug("Removing buckets: \(diff.removedBuckets.joined(separator: ", "))")
        }
        
        do {
            try await storage.removeBuckets(diff.removedBuckets)
            await storage.setTargetCheckpoint(newCheckpoint)
            
            status.update(downloading: true)
        } catch {
            logger.error("Error handling checkpoint diff: \(error.localizedDescription)")
            
            status.update(downloading: false, downloadError: error)
            
            throw SyncError.storageError
        }
    }
    
    // MARK: - Data Handling
    private func handleSyncData(_ bucket: SyncDataBucket, storage: BucketStorage) async throws {
        do {
            try await storage.saveSyncData(SyncDataBatch(buckets: [bucket]))
            
            status.update(downloading:true)
            
        } catch {
            logger.error("Error saving sync data: \(error.localizedDescription)")
            
            status.update(downloading: false, downloadError: error)
            
            throw SyncError.storageError
        }
    }
    
    // MARK: - Keep Alive Handling
    private func handleKeepAlive(tokenExpiresIn: Int) async throws {
        if tokenExpiresIn <= 0 {
            logger.info("Token expired, triggering reconnect")
            state.retry = true
            
            status.update(connected: false, connecting: true)
        } else {
            status.update(connected: true, connecting: false)
        }
    }
    
    // MARK: - State Management
    func resetState() {
        state = SyncStreamState()
        status = SyncStatus()
    }
    
    func isReadyForNextSync() -> Bool {
        return state.appliedCheckpoint == state.targetCheckpoint
    }
    
    var currentBuckets: Set<String> {
        return state.bucketSet
    }
    
    // MARK: - Status Observable
    func observeStatus() -> AnyPublisher<SyncStatusData, Never> {
        return status.asPublisher()
    }
}
