public protocol PowerSyncTransactionProtocol {
    /// Execute a write query and return the number of affected rows
    func execute(
        _ sql: String,
        _ parameters: [Any]?
    ) async throws -> Int64
    
    /// Execute a read-only query and return a single optional result
    func getOptional<RowType>(
        _ sql: String,
        _ parameters: [Any]?,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> RowType?
    
    /// Execute a read-only query and return all results
    func getAll<RowType>(
        _ sql: String,
        _ parameters: [Any]?,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> [RowType]
    
    /// Execute a read-only query and return a single result
    /// Throws if no result is found
    func get<RowType>(
        _ sql: String,
        _ parameters: [Any]?,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> RowType
}

extension PowerSyncTransactionProtocol {
    public func execute(_ sql: String) async throws -> Int64 {
        return try await execute(sql, [])
    }
    
    public func get<RowType>(
        _ sql: String,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> RowType {
        return try await get(sql, [], mapper: mapper)
    }
    
    public func getAll<RowType>(
        _ sql: String,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> [RowType] {
        return try await getAll(sql, [], mapper: mapper)
    }
    
    public func getOptional<RowType>(
        _ sql: String,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> RowType? {
        return try await getOptional(sql, [], mapper: mapper)
    }
}
