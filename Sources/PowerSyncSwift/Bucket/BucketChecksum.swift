import Foundation

struct BucketChecksum: Codable, Equatable {
    let bucket: String
    let checksum: Int
    let count: Int?
    let lastOpId: String?

    enum CodingKeys: String, CodingKey {
        case bucket
        case checksum
        case count
        case lastOpId = "last_op_id"
    }

    init(bucket: String, checksum: Int, count: Int? = nil, lastOpId: String? = nil) {
        self.bucket = bucket
        self.checksum = checksum
        self.count = count
        self.lastOpId = lastOpId
    }
}
