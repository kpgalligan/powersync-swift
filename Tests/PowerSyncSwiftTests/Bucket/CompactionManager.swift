import XCTest
import OSLog
@testable import PowerSyncSwift

struct Bucket: CustomStringConvertible {
    let id: Int64
    let name: String
    let lastAppliedOp: Int64
    let lastOp: Int64
    let targetOp: Int64
    let addChecksum: Int64
    let opChecksum: Int64
    let pendingDelete: Int64
    
    // Custom description for logging
    var description: String {
        return """
        Bucket(
            id: \(id),
            name: "\(name)",
            lastAppliedOp: \(lastAppliedOp),
            lastOp: \(lastOp),
            targetOp: \(targetOp),
            addChecksum: \(addChecksum),
            opChecksum: \(opChecksum),
            pendingDelete: \(pendingDelete)
        )
        """
    }
}

final class CompactionManagerTests: XCTestCase {
    private var database: PowerSyncDatabaseProtocol!
    private var logger: Logger!
    private var sharedDeletes: SharedPendingDeletesActor!
    private var SUT: CompactionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema(tables: [
            Table(name: "users", columns: [
                .text("name"),
                .text("email")
            ])
        ])
        
        database = await KotlinPowerSyncDatabaseImpl(
            schema: schema,
            dbFilename: ":memory:"
        )
        sharedDeletes = SharedPendingDeletesActor()
        logger = Logger(subsystem: "com.powersync.tests", category: "CompactionManagerTests")
        SUT = CompactionManager(
            db: database,
            logger: logger,
            pendingBucketDeletes: sharedDeletes
        )
    }
    
    override func tearDown() async throws {
        database = nil
        SUT = nil
        try await super.tearDown()
    }
    
    // MARK: - Counter Management Tests
    
    func testIncrementCounterTriggersRemoveOpsWhenThresholdReached() async throws {
        let sql = """
        INSERT INTO ps_buckets (
            id, 
            name, 
            last_applied_op, 
            last_op, 
            target_op, 
            add_checksum, 
            op_checksum, 
            pending_delete
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """

        let parameters: [Any] = [
            101, // id
            "user_lists[\"05afe9\"]",
            4711, // last_applied_op
            4711, // last_op
            0,    // target_op
            0,    // add_checksum
            1860477571, // op_checksum
            0     // pending_delete
        ]

        let result = try await database.execute(sql, parameters)
        
        let result2 = try await database.get("SELECT * FROM ps_buckets") {
            cursor in { return Bucket(
                id: Int64(truncating: cursor.getLong(index: 0)!),
                name: cursor.getString(index: 1)!,
                lastAppliedOp: Int64(truncating: cursor.getLong(index: 2)!),
                lastOp: Int64(truncating: cursor.getLong(index: 3)!),
                targetOp: Int64(truncating: cursor.getLong(index: 4)!),
                addChecksum: Int64(truncating: cursor.getLong(index: 5)!),
                opChecksum: Int64(truncating: cursor.getLong(index: 6)!),
                pendingDelete: Int64(truncating: cursor.getLong(index: 7)!)
            )}
        }
        
        logger.info("result2: \(result2())")
        
        await SUT.incrementCounter(1)
        try await SUT.autoCompact()
        

        
//        XCTAssertEqual(res, "lo")
    }
}
