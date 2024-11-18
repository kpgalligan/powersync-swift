import Foundation
import AnyCodable

struct StreamingSyncRequest: Codable {
    let buckets: [BucketRequest]
    let includeChecksum: Bool
    let clientId: String
    let parameters: [String: AnyCodable]
    private let rawData: Bool = true

    enum CodingKeys: String, CodingKey {
        case buckets
        case includeChecksum = "include_checksum"
        case clientId = "client_id"
        case parameters
        case rawData = "raw_data"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.buckets = try container.decode([BucketRequest].self, forKey: .buckets)
        self.includeChecksum = try container.decode(Bool.self, forKey: .includeChecksum)
        self.clientId = try container.decode(String.self, forKey: .clientId)
        self.parameters = try container.decode([String: AnyCodable].self, forKey: .parameters)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(buckets, forKey: .buckets)
        try container.encode(includeChecksum, forKey: .includeChecksum)
        try container.encode(clientId, forKey: .clientId)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(rawData, forKey: .rawData)
    }

    init(buckets: [BucketRequest],
        includeChecksum: Bool = true,
        clientId: String,
        parameters: [String: AnyCodable] = [:]
    ) {
        self.buckets = buckets
        self.includeChecksum = includeChecksum
        self.clientId = clientId
        self.parameters = parameters
    }
}
