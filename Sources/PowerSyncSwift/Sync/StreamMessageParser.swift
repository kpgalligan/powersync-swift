import Foundation
import AnyCodable
import os

class StreamMessageParser {
    enum Message {
        case syncData(SyncDataBucket)
        case checkpoint(Checkpoint)
        case checkpointComplete
        case checkpointDiff(StreamingSyncCheckpointDiff)
        case keepAlive(tokenExpiresIn: Int)
    }
    
    enum ParserError: Error {
        case invalidMessageFormat
        case missingRequiredField(String)
        case invalidDataType(String)
    }
    
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let logger: Logger
    
    init(logger: Logger, decoder: JSONDecoder = JSONDecoder(), encoder: JSONEncoder = JSONEncoder()) {
        self.decoder = decoder
        self.encoder = encoder
        self.logger = logger
    }
    
    func parse(_ jsonString: String) throws -> Message? {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParserError.invalidMessageFormat
        }
        
        let anyCodableJson = json.mapValues { AnyCodable($0) }
        
        do {
            if let syncData = try? parseSyncData(anyCodableJson) {
                return .syncData(syncData)
            }
            if let checkpoint = try? parseCheckpoint(anyCodableJson) {
                return .checkpoint(checkpoint)
            }
            if isCheckpointComplete(json) { // This one stays as [String: Any]
                return .checkpointComplete
            }
            if let diff = try? parseCheckpointDiff(anyCodableJson) {
                return .checkpointDiff(diff)
            }
            if let keepAlive = try parseKeepAlive(json) { // This one stays as [String: Any]
                return .keepAlive(tokenExpiresIn: keepAlive)
            }
        } catch {
            logger.error("Parse error for message: \(jsonString), error: \(error)")
            throw error
        }
        
        return nil
    }
    
    private func parseSyncData(_ json: [String: AnyCodable]) throws -> SyncDataBucket? {
        guard json["data"] != nil else { return nil }
        
        let jsonData = try encoder.encode(json)
        let data = try decoder.decode(SyncDataBucket.self, from: jsonData)
        return data
    }
    
    private func parseCheckpoint(_ json: [String: AnyCodable]) throws -> Checkpoint? {
        guard let checkpointData = json["checkpoint"] else { return nil }
        
        let jsonData = try encoder.encode(checkpointData)
        return try decoder.decode(Checkpoint.self, from: jsonData)
    }
    
    private func isCheckpointComplete(_ json: [String: Any]) -> Bool {
        return json["checkpoint_complete"] != nil
    }
    
    private func parseCheckpointDiff(_ json: [String: AnyCodable]) throws -> StreamingSyncCheckpointDiff? {
        guard let diffData = json["checkpoint_diff"] else { return nil }
        
        let jsonData = try encoder.encode(diffData)
        return try decoder.decode(StreamingSyncCheckpointDiff.self, from: jsonData)
    }
    
    private func parseKeepAlive(_ json: [String: Any]) throws -> Int? {
        guard let tokenExpiresIn = json["token_expires_in"] as? Int else { return nil }
        return tokenExpiresIn
    }
}
