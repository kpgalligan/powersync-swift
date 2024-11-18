import Foundation

struct WriteCheckpointResponse: Codable {
    let data: WriteCheckpointData
}

struct WriteCheckpointData: Codable {
    let writeCheckpoint: String

    enum CodingKeys: String, CodingKey {
        case writeCheckpoint = "write_checkpoint"
    }
}
