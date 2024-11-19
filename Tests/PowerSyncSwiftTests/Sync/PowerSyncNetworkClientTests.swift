//import XCTest
//import Alamofire
//@testable import PowerSyncSwift
//
/// TODO: Figure out how to test this

////class MockPowerSyncBackendConnector: PowerSyncBackendConnector {
////    var mockCredentials: PowerSyncCredentials?
////    var fetchCredentialsError: Error?
////    var fetchCredentialsCalled = false
////    var uploadDataCalled = false
////    
////    override func fetchCredentials() async throws -> PowerSyncCredentials? {
////        fetchCredentialsCalled = true
////        if let error = fetchCredentialsError {
////            throw error
////        }
////        return mockCredentials
////    }
////    
////    override func uploadData(database: PowerSyncDatabaseProtocol) async throws {
////        uploadDataCalled = true
////    }
////}
////
////class PowerSyncNetworkClientTests: XCTestCase {
////    var mockConnector: MockPowerSyncBackendConnector!
////    var client: PowerSyncNetworkClient!
////    
////    let testCredentials = PowerSyncCredentials(
////        endpoint: "https://test.powersync.co",
////        token: "test-token",
////        userId: "test-user"
////    )
////    
////    override func setUp() {
////        super.setUp()
////        mockConnector = MockPowerSyncBackendConnector()
////        client = PowerSyncNetworkClient(connector: mockConnector)
////    }
////    
////    func testGetWriteCheckpoint_SuccessfulCredentialsFetch() async throws {
////        let expectation = expectation(description: "Request should complete")
////        let mockEndpoint = "https://test.powersync.co"
////        let mockClientId = "test-client"
////        let mockResponse = """
////        {
////            "data": {
////                "write_checkpoint": "test-checkpoint"
////            }
////        }
////        """
////        
////        let configuration = URLSessionConfiguration.ephemeral
////        configuration.protocolClasses = [MockURLProtocol.self]
////        let mockSession = Session(configuration: configuration)
////        
////        MockURLProtocol.requestHandler = { request in
////            // Verify request properties
////            XCTAssertEqual(request.url?.host, "test.powersync.co")
////            XCTAssertTrue(request.url?.path.contains("write-checkpoint2.json") ?? false)
////            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Token test-token")
////            
////            return (
////                HTTPURLResponse(url: request.url!,
////                              statusCode: 200,
////                              httpVersion: nil,
////                              headerFields: nil)!,
////                Data(mockResponse.utf8)
////            )
////        }
////        
////        // Create client with mock session
////        mockConnector.mockCredentials = testCredentials
////        client = PowerSyncNetworkClient(connector: mockConnector)
////        
////        // When
////        let checkpoint = try await client.getWriteCheckpoint(clientId: mockClientId)
////        
////        // Then
////        XCTAssertEqual(checkpoint, "test-checkpoint")
////    }
//    
////    func testGetWriteCheckpoint_CredentialsFetchError() async {
////        mockConnector.fetchCredentialsError = PowerSyncError.issueFetchingCredentials
////        
////        do {
////            _ = try await client.getWriteCheckpoint(clientId: "test-client")
////            XCTFail("Expected error to be thrown")
////        } catch {
////            XCTAssertEqual(error as? PowerSyncError, .issueFetchingCredentials)
////        }
////    }
////    
////    func testStreamSync_SuccessfulStream() async throws {
////        let streamRequest = StreamingSyncRequest(
////            buckets: [],
////            clientId: "test-client"
////        )
////        
////        let expectedLines = ["line1", "line2", "line3"]
////        mockSession.streamHandler = { url, method, parameters, encoder, headers in
////            AsyncStream { continuation in
////                Task {
////                    for line in expectedLines {
////                        continuation.yield(line)
////                    }
////                    continuation.finish()
////                }
////            }
////        }
////        
////        let stream = try await client.streamSync(request: streamRequest)
////        var receivedLines: [String] = []
////        
////        for try await line in stream {
////            receivedLines.append(line)
////        }
////        
////        XCTAssertEqual(receivedLines, expectedLines)
////        XCTAssertTrue(mockConnector.fetchCredentialsCalled)
////        XCTAssertEqual(mockSession.lastRequest?.method, .post)
////        XCTAssertTrue(mockSession.lastRequest?.url?.description.contains("sync/stream") ?? false)
////    }
////    
////    func testStreamSync_CredentialsError() async {
////        let streamRequest = StreamingSyncRequest(
////            buckets: [],
////            clientId: "test-client"
////        )
////        mockConnector.fetchCredentialsError = PowerSyncError.issueFetchingCredentials
////        
////        do {
////            let stream = try await client.streamSync(request: streamRequest)
////            for try await _ in stream {
////                XCTFail("Expected error to be thrown")
////            }
////        } catch {
////            XCTAssertEqual(error as? PowerSyncError, .issueFetchingCredentials)
////        }
////    }
////    
////    func testHandleNetworkError_InvalidatesCredentialsOn401() async {
////        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
////        
////        client.handleNetworkError(error)
////        
////        XCTAssertNil(try? await mockConnector.getCredentialsCached())
////    }
////}
//
//class PowerSyncNetworkClientTests: XCTestCase {
//    var mockConnector: MockPowerSyncBackendConnector!
//    var client: PowerSyncNetworkClient!
//    
//    let testCredentials = PowerSyncCredentials(
//        endpoint: "https://test.powersync.co",
//        token: "test-token",
//        userId: "test-user"
//    )
//    
//    override func setUp() {
//        super.setUp()
//        
//        // Setup mock URLSession configuration
//        let configuration = URLSessionConfiguration.default
//        configuration.protocolClasses = [MockURLProtocol.self]
//        
//        mockConnector = MockPowerSyncBackendConnector()
//        mockConnector.mockCredentials = testCredentials
//        
//        client = PowerSyncNetworkClient(connector: mockConnector)
//    }
//    
//    override func tearDown() {
//        MockURLProtocol.requestHandler = nil
//        super.tearDown()
//    }
//    
//    func testGetWriteCheckpoint() async throws {
//        let mockClientId = "test-client"
//        let expectedCheckpoint = "test-checkpoint"
//        let mockResponse = """
//        {
//            "data": {
//                "write_checkpoint": "\(expectedCheckpoint)"
//            }
//        }
//        """
//        
//        MockURLProtocol.requestHandler = { request in
//            // Verify the request
//            XCTAssertTrue(request.url?.absoluteString.contains("write-checkpoint2.json") ?? false)
//            XCTAssertEqual(request.allHTTPHeaderFields?["Authorization"], "Token \(self.testCredentials.token)")
//            XCTAssertEqual(request.allHTTPHeaderFields?["User-Id"], self.testCredentials.userId)
//            
//            let response = HTTPURLResponse(
//                url: request.url!,
//                statusCode: 200,
//                httpVersion: nil,
//                headerFields: ["Content-Type": "application/json"]
//            )!
//            
//            return (response, Data(mockResponse.utf8))
//        }
//    
//        let checkpoint = try await client.getWriteCheckpoint(clientId: mockClientId)
//        
//        XCTAssertEqual(checkpoint, expectedCheckpoint)
//    }
//}
//
//class MockPowerSyncBackendConnector: PowerSyncBackendConnector {
//    var mockCredentials: PowerSyncCredentials?
//    var fetchCredentialsError: Error?
//    
//    override func fetchCredentials() async throws -> PowerSyncCredentials? {
//        if let error = fetchCredentialsError {
//            throw error
//        }
//        return mockCredentials
//    }
//    
//    override func uploadData(database: PowerSyncDatabaseProtocol) async throws {}
//}
//
//class MockURLProtocol: URLProtocol {
//    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
//    
//    override class func canInit(with request: URLRequest) -> Bool {
//        return true
//    }
//    
//    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
//        return request
//    }
//    
//    override func startLoading() {
//        guard let handler = MockURLProtocol.requestHandler else {
//            XCTFail("Missing request handler")
//            return
//        }
//        
//        do {
//            let (response, data) = try handler(request)
//            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
//            client?.urlProtocol(self, didLoad: data)
//            client?.urlProtocolDidFinishLoading(self)
//        } catch {
//            client?.urlProtocol(self, didFailWithError: error)
//        }
//    }
//    
//    override func stopLoading() {}
//}
