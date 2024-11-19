import XCTest
import OSLog
@testable import PowerSyncSwift

final class SyncStreamTests: XCTestCase {
    private var database: PowerSyncDatabaseProtocol!
    private var bucketStorage: BucketStorage!
    private var connector: TestPowerSyncBackendConnector!
    private var logger: Logger!
    private var sut: SyncStream!
    private var uploadCalled = false
    
    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema(tables: [
            Table(name: "users", columns: [
                .text("name"),
                .text("email")
            ])
        ])
        
        database = KotlinPowerSyncDatabaseImpl(
            schema: schema,
            dbFilename: ":memory:"
        )
        
        bucketStorage = BucketStorage(db: database)
        connector = TestPowerSyncBackendConnector()
        logger = Logger(subsystem: "com.powersync.tests", category: "SyncStreamTests")
        
        uploadCalled = false
        sut = SyncStream(
            bucketStorage: bucketStorage,
            connector: connector,
            uploadCrud: { [weak self] in
                self?.uploadCalled = true
            },
            retryDelayMs: 100, // Shorter delay for tests
            logger: logger,
            params: ["test": "params"]
        )
    }
    
    override func tearDown() async throws {
        try await database.disconnectAndClear()
        database = nil
        bucketStorage = nil
        connector = nil
        logger = nil
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - CRUD Upload Tests
    
    func testTriggerCrudUpload_WithValidCredentials_UploadsSuccessfully() async throws {
        // Setup
        let credentials = PowerSyncCredentials(
            endpoint: "https://test.powersync.com",
            token: "valid_token",
            userId: "test_user"
        )
        connector.credentials = credentials
        
        // Insert test CRUD entry
        _ = try await database.execute(
            "INSERT INTO ps_crud (id, tx_id, data) VALUES (?, ?, ?)",
            ["test_id_1", "1", "{\"type\":\"insert\",\"table\":\"users\",\"data\":{\"name\":\"Test User\"}}"]
        )
        
        await sut.stateManager.status.update(connected: true)
        
        // Act
        try await sut.triggerCrudUpload()
        
        // Assert
        XCTAssertTrue(uploadCalled)
        
        // Verify CRUD entry was processed
        let remainingCrud = try await bucketStorage.nextCrudItem()
        XCTAssertNil(remainingCrud)
    }
    
    func testTriggerCrudUpload_WithInvalidCredentials_ThrowsError() async throws {
        // Setup
        connector.shouldFailCredentials = true
        
        await sut.stateManager.status.update(connected: true)
        
        // Act & Assert
        do {
            try await sut.triggerCrudUpload()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? PowerSyncError, .invalidCredentials)
        }
    }
    
    // MARK: - Streaming Sync Tests
    
    func testStreamingSync_WithValidCheckpoint_UpdatesStorage() async throws {
        // Setup
        let testCheckpoint = Checkpoint(
            lastOpId: "test_op_1",
            checksums: [
                BucketChecksum(
                    bucket: "test_bucket",
                    checksum: 123,
                    count: 1,
                    lastOpId: "test_op_1"
                )
            ],
            writeCheckpoint: "write_1"
        )
        
        connector.credentials = PowerSyncCredentials(
            endpoint: "https://test.powersync.com",
            token: "valid_token",
            userId: "test_user"
        )
        
        // Prepare test data in database
        try await database.writeTransaction {
            _ = try await self.database.execute(
                "INSERT INTO ps_buckets (name, target_op) VALUES (?, ?)",
                ["test_bucket", "0"]
            )
        }
        
        let syncExpectation = expectation(description: "Sync process started")
        
        // Act
        Task {
            do {
                try await sut.streamingSync()
                syncExpectation.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        // Wait briefly to allow sync to start
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Simulate receiving checkpoint data
        await bucketStorage.setTargetCheckpoint(testCheckpoint)
        
        await waitForExpectations(timeout: 5)
        
        // Assert
        let bucketStates = try await bucketStorage.getBucketStates()
        XCTAssertEqual(bucketStates.count, 1)
        XCTAssertEqual(bucketStates.first?.bucket, "test_bucket")
    }
}

// MARK: - Test Helpers

class TestPowerSyncBackendConnector: PowerSyncBackendConnector {
    var credentials: PowerSyncCredentials?
    var shouldFailCredentials = false
    
    override func fetchCredentials() async throws -> PowerSyncCredentials? {
        if shouldFailCredentials {
            throw PowerSyncError.invalidCredentials
        }
        return credentials
    }
    
    override func uploadData(database: PowerSyncDatabaseProtocol) async throws {
        // Simulate successful upload
    }
}
