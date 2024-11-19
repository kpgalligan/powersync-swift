//import Foundation
//import PowerSync
//
//final class KotlinInternalDatabase {
//    private var kotlinDatabase: PowerSync.InternalDatabaseImpl
//    private var driver: PowerSync.PsSqlDriver
//
//    init(
//        schema: Schema,
//        dbFilename: String
//    ) {
//        let factory = PowerSync.DatabaseDriverFactory()
//        driver = factory.createDriver(
//            scope: PowerSync.ScopeFactory().createGlobalScope(),
//            dbFilename: dbFilename
//        )
//        self.kotlinDatabase = InternalDatabaseImpl(
//            driver: driver,
//            scope: PowerSync.ScopeFactory().createGlobalScope()
//        )
//    }
//
//    public func connect(
//        connector: PowerSync.PowerSyncBackendConnector,
//        crudThrottleMs: Int64 = 1000,
//        retryDelayMs: Int64 = 5000,
//        params: [String: JsonParam?] = [:]
//    ) async throws {
//
//
//        try await kotlinDatabase.connect(
//            connector: connector,
//            crudThrottleMs: crudThrottleMs,
//            retryDelayMs: retryDelayMs,
//            params: params
//        )
//    }
//
//    public func getCrudBatch(limit: Int32 = 100) async throws -> CrudBatch? {
//        if let kotlinBatch = try await kotlinDatabase.getCrudBatch(limit: limit) {
//            return CrudBatch.fromKotlin(kotlinBatch)
//        }
//        return nil
//    }
//
//    public func getNextCrudTransaction() async throws -> CrudTransaction? {
//        if let kotlinTransaction = try await kotlinDatabase.getNextCrudTransaction() {
//            return CrudTransaction.fromKotlin(kotlinTransaction)
//        }
//        return nil
//    }
//
//    public func getPowerSyncVersion() async throws -> String {
//        try await kotlinDatabase.getPowerSyncVersion()
//    }
//
//    public func disconnect() async throws {
//        try await kotlinDatabase.disconnect()
//    }
//
//    public func disconnectAndClear(clearLocal: Bool = true) async throws {
//        try await kotlinDatabase.disconnectAndClear(clearLocal: clearLocal)
//    }
//
//    public func execute(_ sql: String, _ parameters: [Any]?) async throws -> Int64 {
//        Int64(truncating: try await kotlinDatabase.execute(sql: sql, parameters: parameters))
//    }
//
//    public func get<RowType>(
//        _ sql: String,
//        _ parameters: [Any]?,
//        mapper: @escaping (SqlCursor) -> RowType
//    ) async throws -> RowType {
//        try await kotlinDatabase.get(
//            sql: sql,
//            parameters: parameters,
//            mapper: mapper
//        ) as! RowType
//    }
//
//    public func getAll<RowType>(
//        _ sql: String,
//        _ parameters: [Any]?,
//        mapper: @escaping (SqlCursor) -> RowType
//    ) async throws -> [RowType] {
//        try await kotlinDatabase.getAll(
//            sql: sql,
//            parameters: parameters,
//            mapper: mapper
//        ) as! [RowType]
//    }
//
//    public func getOptional<RowType>(
//        _ sql: String,
//        _ parameters: [Any]?,
//        mapper: @escaping (SqlCursor) -> RowType
//    ) async throws -> RowType? {
//        try await kotlinDatabase.getOptional(
//            sql: sql,
//            parameters: parameters,
//            mapper: mapper
//        ) as! RowType?
//    }
//
//    public func watch<RowType>(
//        _ sql: String,
//        _ parameters: [Any]?,
//        mapper: @escaping (SqlCursor) -> RowType
//    ) -> AsyncStream<[RowType]> {
//        AsyncStream { continuation in
//            Task {
//                for await values in self.kotlinDatabase.watch(
//                    sql: sql,
//                    parameters: parameters,
//                    mapper: mapper
//                ) {
//                    continuation.yield(values as! [RowType])
//                }
//                continuation.finish()
//            }
//        }
//    }
//
//    public func writeTransaction<R>(callback: @escaping (any PowerSyncTransactionProtocol) async throws -> R) async throws -> R {
//        let wrappedCallback = await SuspendTaskWrapper { [kotlinDatabase] in
//            // Create a wrapper that converts the KMP transaction to our Swift protocol
//            if let kmpTransaction = kotlinDatabase as? PowerSyncTransactionProtocol {
//                return try await callback(kmpTransaction)
//            } else {
//                throw PowerSyncError.invalidTransaction
//            }
//        }
//
//        return try await kotlinDatabase.writeTransaction(callback: wrappedCallback) as! R
//    }
//
//    public func readTransaction<R>(callback: @escaping (any PowerSyncTransactionProtocol) async throws -> R) async throws -> R {
//        let wrappedCallback = await SuspendTaskWrapper { [kotlinDatabase] in
//            // Create a wrapper that converts the KMP transaction to our Swift protocol
//            if let kmpTransaction = kotlinDatabase as? PowerSyncTransactionProtocol {
//                return try await callback(kmpTransaction)
//            } else {
//                throw PowerSyncError.invalidTransaction
//            }
//        }
//
//        return try await kotlinDatabase.readTransaction(callback: wrappedCallback) as! R
//    }
//}
