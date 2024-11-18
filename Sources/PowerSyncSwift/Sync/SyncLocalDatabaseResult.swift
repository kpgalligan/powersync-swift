import Foundation

struct SyncLocalDatabaseResult: Codable {
    var ready: Bool = true
    var checkpointValid: Bool = true
    var checkpointFailures: [String]? = nil

    enum CodingKeys: String, CodingKey {
        case ready
        case checkpointValid = "valid"
        case checkpointFailures = "failed_buckets"
    }
    
    init(ready: Bool = true, checkpointValid: Bool = true, checkpointFailures: [String]? = nil) {
        self.ready = ready
        self.checkpointValid = checkpointValid
        self.checkpointFailures = checkpointFailures
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ready = try container.decodeIfPresent(Bool.self, forKey: .ready) ?? true
        checkpointValid = try container.decode(Bool.self, forKey: .checkpointValid)
        checkpointFailures = try container.decodeIfPresent([String].self, forKey: .checkpointFailures)
    }
}

extension SyncLocalDatabaseResult: CustomStringConvertible {
    var description: String {
        return "SyncLocalDatabaseResult<ready=\(ready), checkpointValid=\(checkpointValid), failures=\(checkpointFailures ?? [])>"
    }
}

