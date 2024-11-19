import XCTest
import OSLog
@testable import PowerSyncSwift

final class BucketStorageTests: XCTestCase {
    private var database: PowerSyncDatabaseProtocol!
    private var logger: Logger!
    private var sut: BucketStorage!
    
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
        logger = Logger(subsystem: "com.powersync.tests", category: "BucketStorageTests")
        sut = BucketStorage(db: database)
    }
    
    override func tearDown() async throws {
        try await database.disconnectAndClear()
        database = nil
        sut = nil
        try await super.tearDown()
    }
    
    func testGetMaxOpId() async {
        let maxOpId = await sut.getMaxOpId()
        XCTAssertEqual(maxOpId, "9223372036854775807")
    }
    
    func testGetClientId() async throws {
        let clientId = try await sut.getClientId()
        XCTAssertEqual(clientId, "8b921858-a61b-498e-9b6c-3ec211294b70")
    }
    
    func testNextCrudItem() async throws {
        // Insert test CRUD item
        _ = try await database.execute(
            """
            INSERT INTO \(InternalTable.crud) (id, tx_id, data)
            VALUES (?, ?, ?)
            """,
            ["crud1", "123", "{\"test\":\"data\"}"]
        )
        
        let crudItem = try await sut.nextCrudItem()
        XCTAssertNotNil(crudItem)
        XCTAssertEqual(crudItem?.id, "crud1")
        XCTAssertEqual(crudItem?.transactionId, 123)
    }
    
    func testHasCrud() async throws {
        // Initially should be empty
        let initialHasCrud = try await sut.hasCrud()
        XCTAssertFalse(initialHasCrud)
        
        // Insert test CRUD item
        _ = try await database.execute(
            """
            INSERT INTO ps_crud (id, tx_id, data)
            VALUES (?, ?, ?)
            """,
            ["crud1", "123", "{\"test\":\"data\"}"]
        )
        
        let hasData = try await sut.hasCrud()
        XCTAssertTrue(hasData)
    }
    
//    func testSaveSyncData() async throws {
//        
//        let oplogEntry1 = OplogEntry(
//            checksum: 1234567890,
//            opId: "op_001",
//            rowId: "row_01",
//            rowType: "typeA",
//            op: 1,
//            subkey: "subkey_01",
//            data: "{\"name\":\"John Doe\"}"
//        )
//
//        let oplogEntry2 = OplogEntry(
//            checksum: 9876543210,
//            opId: "op_002",
//            rowId: "row_02",
//            rowType: "typeB",
//            op: 2,
//            subkey: "subkey_02",
//            data: "{\"age\":30}"
//        )
//
//        let oplogEntry3 = OplogEntry(
//            checksum: 1112131415,
//            opId: "op_003",
//            rowId: "row_03",
//            rowType: "typeC",
//            op: 3,
//            subkey: nil,
//            data: nil
//        )
//
//        let syncBucket1 = SyncDataBucket(
//            bucket: "ps_data",
//            data: [oplogEntry1, oplogEntry2],
//            hasMore: true,
//            after: "entry_2",
//            nextAfter: "entry_3"
//        )
//        
//        
//        let syncBucket2 = SyncDataBucket(
//            bucket: "ps_crud",
//            data: [oplogEntry3],
//            hasMore: false,
//            after: "entry_3",
//            nextAfter: nil
//        )
//
//        
//        let syncData = SyncDataBatch(buckets: [
//            syncBucket1, syncBucket2
//        ])
//        
//        try await sut.saveSyncData(syncData)
//        
//        // Verify the operation was saved
//        let operations = try await database.getAll(
//            "SELECT op, data FROM powersync_operations WHERE op = \(OpType.clear.rawValue)",
//            mapper: { cursor in
//                (op: cursor.getString(index: 0)!, data: cursor.getString(index: 1)!)
//            }
//        )
//        
//        XCTAssertEqual(operations.count, 1)
//        XCTAssertEqual(operations[0].op, "save")
//        
//        // Verify the JSON can be decoded back
//        let decodedData = try JSONDecoder().decode(
//            SyncDataBatch.self,
//            from: operations[0].data.data(using: .utf8)!
//        )
//        XCTAssertEqual(decodedData.buckets.count, 1)
//        XCTAssertEqual(decodedData.buckets[0].data.count, 2)
//    }
    
//    func testHasCompletedSync() async throws {
//        // Initially should be false
//        let initial = try await sut.hasCompletedSync()
//        XCTAssertFalse(initial)
//        
//        // Should now be true
//        let completed = try await sut.hasCompletedSync()
//        XCTAssertTrue(completed)
//        
//        // Should stay true on subsequent calls
//        let stillCompleted = try await sut.hasCompletedSync()
//        XCTAssertTrue(stillCompleted)
//    }
    
//    func testSyncLocalDatabase() async throws {
//        // Set up test bucket
//        _ = try await database.execute(
//            """
//            INSERT INTO ps_buckets (
//                name, last_applied_op, last_op, target_op,
//                add_checksum, op_checksum, pending_delete
//            ) VALUES (?, ?, ?, ?, ?, ?, ?)
//            """,
//            ["test_bucket1", 100, 100, 0, 0, 98765, 0]
//        )
//        
//        let checkpoint = Checkpoint(
//            lastOpId: "200",
//            checksums: [
//                BucketChecksum(
//                    bucket: "test_bucket1",
//                    checksum: 98765,
//                    count: 5,
//                    lastOpId: "100"
//                )
//            ],
//            writeCheckpoint: "150"
//        )
//        
//        let result = try await sut.syncLocalDatabase(targetCheckpoint: checkpoint)
//        XCTAssertTrue(result.ready)
//        XCTAssertTrue(result.checkpointValid)
//        
//        // Verify bucket was updated
//        let buckets = try await database.getAll(
//            "SELECT last_op FROM ps_buckets WHERE name = 'test_bucket1'",
//            mapper: { cursor in
//                cursor.getString(index: 0)!
//            }
//        )
//        
//        XCTAssertEqual(buckets.first, "200")
//    }
//    
//    func testSyncLocalDatabaseWithInvalidChecksum() async throws {
//        // Set up test bucket with different checksum
//        _ = try await database.execute(
//            """
//            INSERT INTO ps_buckets (
//                name, last_applied_op, last_op, target_op,
//                add_checksum, op_checksum, pending_delete
//            ) VALUES (?, ?, ?, ?, ?, ?, ?)
//            """,
//            ["test_bucket", 100, 100, 0, 0, 12345, 0]  // Different checksum
//        )
//        
//        let checkpoint = Checkpoint(
//            lastOpId: "200",
//            checksums: [
//                BucketChecksum(
//                    bucket: "test_bucket",
//                    checksum: 98765,  // Different checksum
//                    count: 5,
//                    lastOpId: "100"
//                )
//            ],
//            writeCheckpoint: "150"
//        )
//        
//        let result = try await sut.syncLocalDatabase(targetCheckpoint: checkpoint)
//        XCTAssertFalse(result.ready)
//        XCTAssertFalse(result.checkpointValid)
//        XCTAssertEqual(result.checkpointFailures, ["test_bucket"])
//    }
}
