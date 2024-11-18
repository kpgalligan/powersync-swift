/// A batch of client-side changes.
public struct CrudBatch {
    /// List of client-side changes.
    let crud: [CrudEntry]
    
    /// true if there are more changes in the local queue
    let hasMore: Bool
    
    /// Call to remove the changes from the local queue, once successfully uploaded.
    ///
    /// writeCheckpoint is optional.
    let complete: (String?) async throws -> Void
}
