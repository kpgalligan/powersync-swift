import Foundation

/// A single client-side change.
public struct CrudEntry {
    /// ID of the changed row.
    public let id: String
    
    /// Auto-incrementing client-side id.
    /// Reset whenever the database is re-created.
    public let clientId: Int
    
    /// Type of change.
    public let op: UpdateType
    
    /// Table that contained the change.
    public let table: String
    
    /// Auto-incrementing transaction id. This is the same for all operations
    /// within the same transaction.
    ///
    /// Reset whenever the database is re-created.
    ///
    /// Currently, this is only present when `PowerSyncDatabase.writeTransaction` is used.
    /// This may change in the future.
    public let transactionId: Int?
    
    /// Data associated with the change.
    ///
    /// For PUT, this contains all non-null columns of the row.
    /// For PATCH, this contains the columns that changed.
    /// For DELETE, this is nil.
    public let opData: [String: String?]?
    
    public init(
        id: String,
        clientId: Int,
        op: UpdateType,
        table: String,
        transactionId: Int?,
        opData: [String: String?]?
    ) {
        self.id = id
        self.clientId = clientId
        self.op = op
        self.table = table
        self.transactionId = transactionId
        self.opData = opData
    }
}

extension CrudEntry {
    static func fromRow(_ row: CrudRow) -> CrudEntry {
        let jsonData = row.data.data(using: .utf8)
        let json = try? JSONSerialization.jsonObject(with: jsonData!) as? [String: Any]
        let id = json?["id"] as? String
        let opString = json?["op"] as? String
        let table = json?["type"] as? String
        
        
        var opData: [String: String?]?
        if let data = json?["data"] as? [String: Any] {
            opData = data.mapValues { value in
                value as? String
            }
        }
        
        return CrudEntry(
            id: id!,
            clientId: Int(row.id)!,
            op: UpdateType.fromJSON(opString!)!,
            table: table!,
            transactionId: row.txId,
            opData: opData
        )
    }
}

extension CrudEntry: CustomStringConvertible {
    public var description: String {
        return "CrudEntry<\(transactionId ?? 0)/\(clientId) \(op.toJSON()) \(table)/\(id) \(String(describing: opData))>"
    }
}

enum CrudError: Error {
    case invalidJSON
}
