import XCTest
@testable import PowerSyncSwift

// Mock implementation for testing
class MockBackendConnector: PowerSyncBackendConnector {
    var fetchCredentialsCalled = false
    var uploadDataCalled = false
    var shouldThrowError = false
    var mockCredentials: PowerSyncSwift.PowerSyncCredentials?
    
    override func fetchCredentials() async throws -> PowerSyncSwift.PowerSyncCredentials? {
        fetchCredentialsCalled = true
        if shouldThrowError {
            throw MockError.fetchFailed
        }
        return mockCredentials
    }
    
    override func uploadData(database: PowerSyncDatabaseProtocol) async throws {
        uploadDataCalled = true
        if shouldThrowError {
            throw MockError.uploadFailed
        }
    }
    
    enum MockError: Error {
        case fetchFailed
        case uploadFailed
    }
}

class PowerSyncTests: XCTestCase {
    private var connector: MockBackendConnector!
    private var database: PowerSyncDatabaseProtocol!
    
    override func setUp() async throws {
        try await super.setUp()
        connector = MockBackendConnector()
        // Create a test schema
        let schema = Schema(tables: [
            Table(name: "users", columns: [
                .text("name"),
                .text("email")
            ])
        ])
        
        // Use an in-memory database for testing
        database = await KotlinPowerSyncDatabaseImpl(
            schema: schema,
            dbFilename: ":memory:"
        )
        
    }
    
    override func tearDown() {
        connector = nil
        database = nil
        super.tearDown()
    }
    
    func testFetchCredentialsSuccess() async throws {
        let expectedCredentials = PowerSyncSwift.PowerSyncCredentials(
            endpoint: "https://test.powersync.co",
            token: "test-token",
            userId: "test-user"
        )
        connector.mockCredentials = expectedCredentials
        
        let credentials = try await connector.fetchCredentials()
        
        XCTAssertTrue(connector.fetchCredentialsCalled)
        XCTAssertEqual(credentials?.endpoint, expectedCredentials.endpoint)
        XCTAssertEqual(credentials?.token, expectedCredentials.token)
        XCTAssertEqual(credentials?.userId, expectedCredentials.userId)
    }
    
    func testFetchCredentialsFailure() async {
        connector.shouldThrowError = true
        
        do {
            _ = try await connector.fetchCredentials()
            XCTFail("Expected fetchCredentials to throw an error")
        } catch {
            XCTAssertTrue(connector.fetchCredentialsCalled)
            XCTAssertTrue(error is MockBackendConnector.MockError)
        }
    }
    
    func testUploadDataSuccess() async throws {
        try await connector.uploadData(database: database)
        XCTAssertTrue(connector.uploadDataCalled)
    }
    
    func testUploadDataFailure() async {
        connector.shouldThrowError = true
        
        do {
            try await connector.uploadData(database: database)
            XCTFail("Expected uploadData to throw an error")
        } catch {
            XCTAssertTrue(connector.uploadDataCalled)
            XCTAssertTrue(error is MockBackendConnector.MockError)
        }
    }
    
    func testGetCredentialsCached() async throws {
        let expectedCredentials = PowerSyncSwift.PowerSyncCredentials(
            endpoint: "https://test.powersync.co",
            token: "test-token",
            userId: "test-user"
        )
        connector.mockCredentials = expectedCredentials
        
        // First call should fetch new credentials
        let credentials1 = try await connector.getCredentialsCached()
        XCTAssertNotNil(credentials1)
        XCTAssertEqual(credentials1?.endpoint, expectedCredentials.endpoint)
        
        // Second call should return cached credentials
        let credentials2 = try await connector.getCredentialsCached()
        XCTAssertNotNil(credentials2)
        XCTAssertEqual(credentials2?.endpoint, expectedCredentials.endpoint)
    }
    
    func testInvalidateCredentials() async throws {
        let expectedCredentials = PowerSyncSwift.PowerSyncCredentials(
            endpoint: "https://test.powersync.co",
            token: "test-token",
            userId: "test-user"
        )
        connector.mockCredentials = expectedCredentials
        
        // Get initial credentials
        let credentials1 = try await connector.getCredentialsCached()
        XCTAssertNotNil(credentials1)
        
        // Invalidate credentials
        connector.invalidateCredentials()
        
        // Should fetch new credentials
        connector.mockCredentials = PowerSyncCredentials(
            endpoint: "https://new.powersync.co",
            token: "new-token",
            userId: "new-user"
        )
        
        let credentials2 = try await connector.getCredentialsCached()
        XCTAssertNotNil(credentials2)
        XCTAssertEqual(credentials2?.endpoint, "https://new.powersync.co")
    }
    
    func testPrefetchCredentials() async throws {
        let expectation = XCTestExpectation(description: "Prefetch completed")
        
        Task {
            _ = connector.prefetchCredentials()
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
