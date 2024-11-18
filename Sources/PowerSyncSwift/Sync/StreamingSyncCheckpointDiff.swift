import Foundation

struct StreamingSyncCheckpointDiff: Codable {
    let lastOpId: String
    let updatedBuckets: [BucketChecksum]
    let removedBuckets: [String]
    let writeCheckpoint: String?

    enum CodingKeys: String, CodingKey {
        case lastOpId = "last_op_id"
        case updatedBuckets = "updated_buckets"
        case removedBuckets = "removed_buckets"
        case writeCheckpoint = "write_checkpoint"
    }

    init(lastOpId: String, updatedBuckets: [BucketChecksum], removedBuckets: [String], writeCheckpoint: String? = nil) {
        self.lastOpId = lastOpId
        self.updatedBuckets = updatedBuckets
        self.removedBuckets = removedBuckets
        self.writeCheckpoint = writeCheckpoint
    }
}
