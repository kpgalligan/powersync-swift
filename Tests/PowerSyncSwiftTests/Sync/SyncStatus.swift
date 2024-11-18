import XCTest
import Combine
@testable import PowerSyncSwift

final class SyncStatusTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    func testInitialState() {
        let status = SyncStatus.empty()
        
        XCTAssertFalse(status.connected)
        XCTAssertFalse(status.connecting)
        XCTAssertFalse(status.downloading)
        XCTAssertFalse(status.uploading)
        XCTAssertNil(status.lastSyncedAt)
        XCTAssertNil(status.hasSynced)
        XCTAssertNil(status.uploadError)
        XCTAssertNil(status.downloadError)
        XCTAssertNil(status.anyError)
    }
    
    func testUpdateAllProperties() {
        let status = SyncStatus.empty()
        let date = Date()
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        
        status.update(
            connected: true,
            connecting: true,
            downloading: true,
            uploading: true,
            hasSynced: true,
            lastSyncedAt: date,
            uploadError: error,
            downloadError: error
        )
        
        XCTAssertTrue(status.connected)
        XCTAssertTrue(status.connecting)
        XCTAssertTrue(status.downloading)
        XCTAssertTrue(status.uploading)
        XCTAssertEqual(status.lastSyncedAt, date)
        XCTAssertTrue(status.hasSynced!)
        XCTAssertNotNil(status.uploadError)
        XCTAssertNotNil(status.downloadError)
        XCTAssertNotNil(status.anyError)
    }
    
    func testPartialUpdate() {
        let status = SyncStatus.empty()
        
        status.update(connected: true, downloading: true)
        
        XCTAssertTrue(status.connected)
        XCTAssertFalse(status.connecting)
        XCTAssertTrue(status.downloading)
        XCTAssertFalse(status.uploading)
    }
    
    func testClearErrors() {
        let status = SyncStatus.empty()
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        
        // Set initial errors
        status.update(uploadError: error, downloadError: error)
        XCTAssertNotNil(status.uploadError)
        XCTAssertNotNil(status.downloadError)
        
        // Clear upload error
        status.update(clearUploadError: true)
        XCTAssertNil(status.uploadError)
        XCTAssertNotNil(status.downloadError)
        
        // Clear download error
        status.update(clearDownloadError: true)
        XCTAssertNil(status.uploadError)
        XCTAssertNil(status.downloadError)
        XCTAssertNil(status.anyError)
    }
    
    func testPublisher() {
        let status = SyncStatus.empty()
        let expectation = XCTestExpectation(description: "Publisher updates")
        var updateCount = 0
        
        status.asPublisher()
            .sink { syncStatus in
                updateCount += 1
                
                if updateCount == 1 {
                    // Initial state
                    XCTAssertFalse(syncStatus.connected)
                } else if updateCount == 2 {
                    // After update
                    XCTAssertTrue(syncStatus.connected)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        status.update(connected: true)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(updateCount, 2)
    }
    
    func testAnyErrorBehavior() {
        let status = SyncStatus.empty()
        let uploadError = NSError(domain: "upload", code: 1, userInfo: nil)
        let downloadError = NSError(domain: "download", code: 2, userInfo: nil)
        
        // Test upload error only
        status.update(uploadError: uploadError)
        XCTAssertNotNil(status.anyError)
        XCTAssertEqual((status.anyError as? NSError)?.domain, "upload")
        
        // Test download error takes precedence
        status.update(downloadError: downloadError)
        XCTAssertNotNil(status.anyError)
        XCTAssertEqual((status.anyError as? NSError)?.domain, "download")
        
        // Test clearing download error falls back to upload error
        status.update(clearDownloadError: true)
        XCTAssertNotNil(status.anyError)
        XCTAssertEqual((status.anyError as? NSError)?.domain, "upload")
        
        // Test clearing both errors
        status.update(clearUploadError: true, clearDownloadError: true)
        XCTAssertNil(status.anyError)
    }
    
    func testDescription() {
        let status = SyncStatus.empty()
        let date = Date()
        
        status.update(
            connected: true,
            downloading: true,
            hasSynced: true,
            lastSyncedAt: date
        )
        
        let description = status.description
        XCTAssertTrue(description.contains("connected=true"))
        XCTAssertTrue(description.contains("downloading=true"))
        XCTAssertTrue(description.contains("hasSynced=Optional(true)"))
        XCTAssertTrue(description.contains(String(describing: date)))
    }
}
