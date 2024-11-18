import Foundation

struct ChecksumCache: Codable, Equatable {
    let lastOpId: String
    let checksums: [String: BucketChecksum]

    enum CodingKeys: String, CodingKey {
        case lastOpId = "last_op_id"
        case checksums
    }
}
