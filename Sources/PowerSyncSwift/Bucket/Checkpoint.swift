import Foundation

struct Checkpoint: Codable, Equatable {
    let lastOpId: String
    let checksums: [BucketChecksum]
    let writeCheckpoint: String?

    enum CodingKeys: String, CodingKey {
        case lastOpId = "last_op_id"
        case checksums = "buckets"
        case writeCheckpoint = "write_checkpoint"
    }

    func clone() -> Checkpoint {
        return Checkpoint(lastOpId: self.lastOpId, checksums: self.checksums, writeCheckpoint: self.writeCheckpoint)
    }
}

extension Checkpoint: CustomStringConvertible {
    var description: String {
        return "Checkpoint<lastOpId:\(lastOpId), checksums:\(checksums), writeCheckpoint:\(writeCheckpoint ?? "nil")>"
    }
}
