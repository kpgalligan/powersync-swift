import Foundation
import Combine
import AnyCodable
import OSLog

actor SyncStream {
    private let bucketStorage: BucketStorage
    private let connector: PowerSyncBackendConnector
    private let uploadCrud: () async throws -> Void
    private let retryDelayMs: Int64
    private let logger: Logger
    private let params: [String: AnyCodable]
    private let networkClient: PowerSyncNetworkClient
    private let messageParser: StreamMessageParser
    public let stateManager: SyncStateManager
    
    private var isUploadingCrud: Bool = false
    private var clientId: String?
    
    init(
        bucketStorage: BucketStorage,
        connector: PowerSyncBackendConnector,
        uploadCrud: @escaping () async throws -> Void,
        retryDelayMs: Int64 = 5000,
        logger: Logger,
        params: [String: AnyCodable]
    ) {
        self.bucketStorage = bucketStorage
        self.connector = connector
        self.uploadCrud = uploadCrud
        self.retryDelayMs = retryDelayMs
        self.logger = logger
        self.params = params
        self.networkClient = PowerSyncNetworkClient(connector: connector)
        self.messageParser = StreamMessageParser(logger: logger)
        self.stateManager = SyncStateManager(logger: logger)
    }
    
    func invalidateCredentials() {
        connector.invalidateCredentials()
    }
    
    func streamingSync() async throws {
        var invalidCredentials = false
        clientId = try await bucketStorage.getClientId()
        
        while true {
            stateManager.status.update(connecting: true)
            
            do {
                if invalidCredentials {
                    invalidateCredentials()
                    invalidCredentials = false
                }
                
                try await streamingSyncIteration()
            } catch {
                if error is CancellationError {
                    throw error
                }
                
                logger.error("Error in streamingSync: \(error.localizedDescription)")
                invalidCredentials = true
                stateManager.status.update(downloadError: error)
            }
            
            stateManager.status.update(
                connected: false,
                connecting: true,
                downloading: false
            )
            
            try await Task.sleep(nanoseconds: UInt64(retryDelayMs) * 1_000_000)
        }
    }
    
    func triggerCrudUpload() async throws {
        guard stateManager.status.connected, !isUploadingCrud else { return }
        
        isUploadingCrud = true
        try await uploadAllCrud()
        isUploadingCrud = false
    }
    
    private func uploadAllCrud() async throws {
        var checkedCrudItem: CrudEntry?
        
        while true {
            stateManager.status.update(uploading: true)
            
            do {
                if let nextCrudItem = try await bucketStorage.nextCrudItem() {
                    if nextCrudItem.clientId == checkedCrudItem?.clientId {
                        logger.warning("""
                            Potentially previously uploaded CRUD entries are still present in the upload queue.
                            Make sure to handle uploads and complete CRUD transactions or batches by calling and awaiting their [.complete()] method.
                            The next upload iteration will be delayed.
                            """)
                        throw SyncStreamError.delayingPreviousCrudItem
                    }
                    
                    checkedCrudItem = nextCrudItem
                    try await uploadCrud()
                } else {
                    let writeCheckpoint = try await getWriteCheckpoint()
                    _ = try await bucketStorage.updateLocalTarget { writeCheckpoint }
                    break
                }
            } catch {
                logger.error("Error uploading crud: \(error.localizedDescription)")
                stateManager.status.update(uploading: false, uploadError: error)
                try await Task.sleep(nanoseconds: UInt64(retryDelayMs) * 1_000_000)
                break
            }
        }
        
        stateManager.status.update(uploading: false)
    }
    
    private func getWriteCheckpoint() async throws -> String {
        guard let clientId = clientId else {
            throw SyncStreamError.missingClientId
        }
        return try await networkClient.getWriteCheckpoint(clientId: clientId)
    }
    
    private func streamingSyncIteration() async throws {
        let bucketEntries = try await bucketStorage.getBucketStates()
        let initialBuckets = Dictionary(
            uniqueKeysWithValues: bucketEntries.map { ($0.bucket, $0.opId) }
        )
        
        let request = StreamingSyncRequest(
            buckets: initialBuckets.map { BucketRequest(name: $0.key, after: $0.value) },
            clientId: clientId!,
            parameters: params
        )
        
        let stream = try await networkClient.streamSync(request: request)
        
        for try await line in stream {
            if let message = try messageParser.parse(line) {
                try await stateManager.handleMessage(message, storage: bucketStorage)
            } else {
                logger.warning("Unhandled instruction: \(line)")
            }
        }
    }
}

enum SyncStreamError: Error {
    case invalidCredentials
    case missingClientId
    case delayingPreviousCrudItem
    case streamError(String)
}
