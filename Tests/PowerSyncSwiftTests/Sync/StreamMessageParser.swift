import XCTest
import AnyCodable
import os
@testable import PowerSyncSwift // Replace with your actual module name

class StreamMessageParserTests: XCTestCase {
    var parser: StreamMessageParser!
    var logger: Logger!
    
    override func setUp() {
        super.setUp()
        logger = Logger(subsystem: "com.test.powersync", category: "StreamMessageParserTests")
        parser = StreamMessageParser(logger: logger)
    }
    
    func testParseSyncData() throws {
        let json = """
        {
            "bucket": "users",
            "data": [
                {
                    "checksum": 12345678,
                    "op_id": "op123",
                    "object_id": "user1",
                    "object_type": "user",
                    "op": 3,
                    "subkey": "profile",
                    "data": "{\\"name\\":\\"John Doe\\",\\"email\\":\\"john@example.com\\"}"
                },
                {
                    "checksum": 87654321,
                    "op_id": "op124",
                    "object_id": "user2",
                    "object_type": "user",
                    "op": 2,
                    "subkey": "settings",
                    "data": "{\\"theme\\":\\"dark\\",\\"notifications\\":true}"
                }
            ],
            "has_more": true,
            "after": "cursor123",
            "next_after": "cursor124"
        }
        """

        let message = try parser.parse(json)
        
        guard case let .syncData(syncData) = message else {
            XCTFail("Expected syncData message")
            return
        }
        
        XCTAssertEqual(syncData.bucket, "users")
        XCTAssertEqual(syncData.data.count, 2)
    }
    
    func testParseCheckpoint() throws {
        let json = """
        {
            "checkpoint": {
                "last_op_id": "op_789",
                "buckets": [
                    {
                        "bucket": "users",
                        "checksum": 123456,
                        "count": 50,
                        "last_op_id": "op_456"
                    }
                ],
                "write_checkpoint": "write_cp_123"
            }
        }
        """
        
        let message = try parser.parse(json)
        
        guard case let .checkpoint(checkpoint) = message else {
            XCTFail("Expected checkpoint message")
            return
        }
        
        
        XCTAssertEqual(checkpoint.lastOpId, "op_789")
        XCTAssertEqual(checkpoint.writeCheckpoint, "write_cp_123")
        XCTAssertEqual(checkpoint.checksums.count, 1)
        
        let bucket = checkpoint.checksums[0]
        XCTAssertEqual(bucket.bucket, "users")
        XCTAssertEqual(bucket.checksum, 123456)
        XCTAssertEqual(bucket.count, 50)
        XCTAssertEqual(bucket.lastOpId, "op_456")
    }
    
    func testParseCheckpointComplete() throws {
        let json = """
        {
            "checkpoint_complete": true
        }
        """
        
        let message = try parser.parse(json)
        
        guard case .checkpointComplete = message else {
            XCTFail("Expected checkpointComplete message")
            return
        }
    }
    
    func testParseCheckpointDiff() throws {
        let json = """
        {
            "checkpoint_diff": {
                "last_op_id": "op_999",
                "updated_buckets": [
                    {
                        "bucket": "users",
                        "checksum": 123456,
                        "count": 55,
                        "last_op_id": "op_456"
                    },
                    {
                        "bucket": "photos",
                        "checksum": 789012,
                        "count": null,
                        "last_op_id": null
                    }
                ],
                "removed_buckets": ["documents", "archived_items"],
                "write_checkpoint": "write_cp_456"
            }
        }
        """
        
        let message = try parser.parse(json)
        
        guard case let .checkpointDiff(diff) = message else {
            XCTFail("Expected checkpointDiff message")
            return
        }
        
        XCTAssertEqual(diff.lastOpId, "op_999")
        XCTAssertEqual(diff.writeCheckpoint, "write_cp_456")
        XCTAssertEqual(diff.updatedBuckets.count, 2)
        XCTAssertEqual(diff.removedBuckets.count, 2)
        
        let firstBucket = diff.updatedBuckets[0]
        XCTAssertEqual(firstBucket.bucket, "users")
        XCTAssertEqual(firstBucket.checksum, 123456)
        XCTAssertEqual(firstBucket.count, 55)
        XCTAssertEqual(firstBucket.lastOpId, "op_456")
        
        let secondBucket = diff.updatedBuckets[1]
        XCTAssertEqual(secondBucket.bucket, "photos")
        XCTAssertEqual(secondBucket.checksum, 789012)
        XCTAssertNil(secondBucket.count)
        XCTAssertNil(secondBucket.lastOpId)
        
        XCTAssertEqual(diff.removedBuckets, ["documents", "archived_items"])
    }
    
    func testParseKeepAlive() throws {
        let json = """
        {
            "token_expires_in": 3600
        }
        """
        
        let message = try parser.parse(json)
        
        guard case let .keepAlive(expiresIn) = message else {
            XCTFail("Expected keepAlive message")
            return
        }
        
        XCTAssertEqual(expiresIn, 3600)
    }

    func testParseUnknownMessageType() throws {
        let json = """
        {
            "unknown_type": "some_value"
        }
        """
        
        let message = try parser.parse(json)
        XCTAssertNil(message, "Unknown message type should return nil")
    }
    
    func testParseEmptyObject() throws {
        let json = "{}"
        
        let message = try parser.parse(json)
        XCTAssertNil(message, "Empty object should return nil")
    }
}
