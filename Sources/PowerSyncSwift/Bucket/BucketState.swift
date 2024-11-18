import Foundation

struct BucketState: Codable {
    let bucket: String
    let opId: String

    enum CodingKeys: String, CodingKey {
        case bucket
        case opId = "op_id"
    }
}

extension BucketState: CustomStringConvertible {
    var description: String {
        return "BucketState<\(bucket):\(opId)>"
    }
}
