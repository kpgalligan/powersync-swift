import Foundation

/// A transaction of client-side changes.
public struct CrudTransaction {
    /// Unique transaction id.
    ///
    /// If nil, this contains a list of changes recorded without an explicit transaction associated.
    let transactionId: Int?
    
    /// List of client-side changes.
    public let crud: [CrudEntry]
    
    /// Call to remove the changes from the local queue, once successfully uploaded.
    ///
    /// writeCheckpoint is optional.
    public let complete: (String?) async throws -> Void
    
    public var description: String {
        "CrudTransaction<\(String(describing: transactionId)), \(crud)>"
    }
}
