import Foundation

struct SyncDataBucket: Codable {
    let bucket: String
    let data: [OplogEntry]
    let hasMore: Bool
    let after: String?
    let nextAfter: String?

    enum CodingKeys: String, CodingKey {
        case bucket
        case data
        case hasMore = "has_more"
        case after
        case nextAfter = "next_after"
    }

    init(bucket: String, data: [OplogEntry], hasMore: Bool = false, after: String? = nil, nextAfter: String? = nil) {
        self.bucket = bucket
        self.data = data
        self.hasMore = hasMore
        self.after = after
        self.nextAfter = nextAfter
    }
}
