import XCTest
import OSLog
@testable import PowerSyncSwift

final class BucketStateManagerTests: XCTestCase {
    private var database: PowerSyncDatabaseProtocol!
    private var logger: Logger!
    private var sharedDeletes: SharedPendingDeletesActor!
    private var SUT: BucketStateManager!
    
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
        logger = Logger(subsystem: "com.powersync.tests", category: "BucketStateManagerTests")
        sharedDeletes = SharedPendingDeletesActor()
        SUT = BucketStateManager(
            db: database,
            logger: logger,
            pendingBucketDeletes: sharedDeletes
        )
    }
    
    override func tearDown() async throws {
        try await database.disconnectAndClear()
        database = nil
        sharedDeletes = nil
        SUT = nil
        try await super.tearDown()
    }
    
    func testGetBucketStates() async throws {
        let sql = """
        INSERT INTO ps_buckets (
            name, 
            last_applied_op, 
            last_op, 
            target_op, 
            add_checksum, 
            op_checksum, 
            pending_delete
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        let parameters: [Any] = [
            "user_lists[\"05afe9\"]",
            4711, // last_applied_op
            4711, // last_op
            0,    // target_op
            0,    // add_checksum
            1860477571, // op_checksum
            0     // pending_delete
        ]

        _ = try await database.execute(sql, parameters)
        
        let states = try await SUT.getBucketStates()
        
        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states[0].bucket, "user_lists[\"05afe9\"]")
        XCTAssertEqual(states[0].opId, "4711")
    }
    
    func testDeleteBucket() async throws {
        let isPendingDeleteBefore = await sharedDeletes.getPendingBucketDeletes()
        XCTAssertFalse(isPendingDeleteBefore)

        try await SUT.deleteBucket("test_bucket")
        
        let isPendingDeleteAfter = await sharedDeletes.getPendingBucketDeletes()
        XCTAssertTrue(isPendingDeleteAfter)
    }
        
    func testRemoveBuckets() async throws {
        let isPendingDeleteBefore = await sharedDeletes.getPendingBucketDeletes()
        XCTAssertFalse(isPendingDeleteBefore)
        

        let bucketsToDelete = ["bucket1", "bucket2"]
        try await SUT.removeBuckets(bucketsToDelete)
        
        let isPendingDeleteAfter = await sharedDeletes.getPendingBucketDeletes()
        XCTAssertTrue(isPendingDeleteAfter)
    }
    
    func testUpdateBucketsWithCheckpoint() async throws {
        let insertSql = """
        INSERT INTO ps_buckets (
            name, 
            last_applied_op, 
            last_op, 
            target_op, 
            add_checksum, 
            op_checksum, 
            pending_delete
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        _ = try await database.execute(insertSql, ["bucket8", 100, 100, 0, 0, 12345, 0])
        
        let checkpoint = Checkpoint(
            lastOpId: "200",
            checksums: [
                BucketChecksum(
                    bucket: "bucket8",
                    checksum: 54321,
                    count: 10,
                    lastOpId: "200"
                )
            ],
            writeCheckpoint: "150"
        )
        
        try await SUT.updateBucketsWithCheckpoint(checkpoint)
        
        let buckets = try await database.getAll(
            "SELECT name, last_op FROM ps_buckets WHERE name = 'bucket8'",
            mapper: { cursor in
                (name: cursor.getString(index: 0)!, lastOp: cursor.getString(index: 1)!)
            }
        )
        
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets[0].lastOp, "200")
        
        let localBucket = try await database.getAll(
            "SELECT last_op FROM ps_buckets WHERE name = '$local'",
            mapper: { cursor in
                cursor.getString(index: 0)!
            }
        )
        
        XCTAssertEqual(localBucket.first, "150")
    }
    
    func testValidateChecksums() async throws {
        let checkpoint = Checkpoint(
            lastOpId: "100",
            checksums: [
                BucketChecksum(
                    bucket: "test_bucket",
                    checksum: 98765,
                    count: 5,
                    lastOpId: "100"
                )
            ],
            writeCheckpoint: nil
        )
        
        // Insert a bucket to validate against
        let insertSql = """
        INSERT INTO ps_buckets (
            name, 
            last_applied_op, 
            last_op, 
            target_op, 
            add_checksum, 
            op_checksum, 
            pending_delete
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        _ = try await database.execute(
            insertSql,
            ["test_bucket", 100, 100, 0, 0, 98765, 0]
        )
        
        let result = try await SUT.validateChecksums(checkpoint)
        
        XCTAssertTrue(result.checkpointValid)
    }
    
    func testValidateChecksumsWithMismatchedChecksums() async throws {
        let checkpoint = Checkpoint(
            lastOpId: "100",
            checksums: [
                BucketChecksum(
                    bucket: "test_bucket",
                    checksum: 98765, // Different from what's in the database
                    count: 5,
                    lastOpId: "100"
                )
            ],
            writeCheckpoint: nil
        )
        
        // Insert a bucket with different checksum
        let insertSql = """
        INSERT INTO ps_buckets (
            name, 
            last_applied_op, 
            last_op, 
            target_op, 
            add_checksum, 
            op_checksum, 
            pending_delete
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        _ = try await database.execute(
            insertSql,
            ["test_bucket", 100, 100, 0, 0, 12345, 0] // Different checksum
        )
        
        let result = try await SUT.validateChecksums(checkpoint)
        XCTAssertFalse(result.checkpointValid)
    }
    
    func testDeleteBucketAndValidateChecksums() async throws {
        // First set up a bucket
        let insertSql = """
        INSERT INTO ps_buckets (
            name, 
            last_applied_op, 
            last_op, 
            target_op, 
            add_checksum, 
            op_checksum, 
            pending_delete
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        _ = try await database.execute(
            insertSql,
            ["test_bucket", 100, 100, 0, 0, 98765, 0]
        )
        
        // Delete the bucket
        try await SUT.deleteBucket("test_bucket")
        
        // Try to validate a checkpoint containing the deleted bucket
        let checkpoint = Checkpoint(
            lastOpId: "100",
            checksums: [
                BucketChecksum(
                    bucket: "test_bucket",
                    checksum: 98765,
                    count: 5,
                    lastOpId: "100"
                )
            ],
            writeCheckpoint: nil
        )
        
        let result = try await SUT.validateChecksums(checkpoint)
        XCTAssertFalse(result.checkpointValid)
        XCTAssertEqual(result.checkpointFailures, ["test_bucket"])
    }
}
