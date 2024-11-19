import Foundation
import PowerSync

class KotlinPowerSyncDatabaseImpl: PowerSyncDatabaseProtocol {
    private var kotlinDatabase: PowerSync.PowerSyncDatabase

    var currentStatus: PowerSync.SyncStatus {
        get { kotlinDatabase.currentStatus }
    }

    init(
        schema: Schema,
        dbFilename: String
    ) {
        let factory = PowerSync.DatabaseDriverFactory()
        let driver = factory.createDriver(
            scope: PowerSync.ScopeFactory().createGlobalScope(),
            dbFilename: dbFilename
        )
        self.kotlinDatabase = PowerSyncDatabase(
            factory: factory,
            schema: KotlinAdapter.Schema.toKotlin(schema),
            dbFilename: dbFilename
        )
    }

    init(kotlinDatabase: PowerSync.PowerSyncDatabase) {
        self.kotlinDatabase = kotlinDatabase
    }

    public func asKotlinDatabase() -> PowerSync.PowerSyncDatabase {
        return kotlinDatabase
    }

    public func waitForFirstSync() async throws {
//        try await kotlinDatabase.waitForFirstSync()
    }

    public func connect(
        connector: PowerSync.PowerSyncBackendConnector,
        crudThrottleMs: Int64 = 1000,
        retryDelayMs: Int64 = 5000,
        params: [String: JsonParam?] = [:]
    ) async throws {


        try await kotlinDatabase.connect(
            connector: connector,
            crudThrottleMs: crudThrottleMs,
            retryDelayMs: retryDelayMs,
            params: params
        )
    }

    public func getCrudBatch(limit: Int32 = 100) async throws -> CrudBatch? {
        if let kotlinBatch = try await kotlinDatabase.getCrudBatch(limit: limit) {
            return CrudBatch.fromKotlin(kotlinBatch)
        }
        return nil
    }

    public func getNextCrudTransaction() async throws -> CrudTransaction? {
        if let kotlinTransaction = try await kotlinDatabase.getNextCrudTransaction() {
            return CrudTransaction.fromKotlin(kotlinTransaction)
        }
        return nil
    }

    public func getPowerSyncVersion() async throws -> String {
        try await kotlinDatabase.getPowerSyncVersion()
    }

    public func disconnect() async throws {
        try await kotlinDatabase.disconnect()
    }

    public func disconnectAndClear(clearLocal: Bool = true) async throws {
        try await kotlinDatabase.disconnectAndClear(clearLocal: clearLocal)
    }

    public func execute(_ sql: String, _ parameters: [Any]?) async throws -> Int64 {
        Int64(truncating: try await kotlinDatabase.execute(sql: sql, parameters: parameters))
    }

    public func get<RowType>(
        _ sql: String,
        _ parameters: [Any]?,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> RowType {
        try await kotlinDatabase.get(
            sql: sql,
            parameters: parameters,
            mapper: mapper
        ) as! RowType
    }

    public func getAll<RowType>(
        _ sql: String,
        _ parameters: [Any]?,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> [RowType] {
        try await kotlinDatabase.getAll(
            sql: sql,
            parameters: parameters,
            mapper: mapper
        ) as! [RowType]
    }

    public func getOptional<RowType>(
        _ sql: String,
        _ parameters: [Any]?,
        mapper: @escaping (SqlCursor) -> RowType
    ) async throws -> RowType? {
        try await kotlinDatabase.getOptional(
            sql: sql,
            parameters: parameters,
            mapper: mapper
        ) as! RowType?
    }

    public func watch<RowType>(
        _ sql: String,
        _ parameters: [Any]?,
        mapper: @escaping (SqlCursor) -> RowType
    ) -> AsyncStream<[RowType]> {
        AsyncStream { continuation in
            Task {
                for await values in self.kotlinDatabase.watch(
                    sql: sql,
                    parameters: parameters,
                    mapper: mapper
                ) {
                    continuation.yield(values as! [RowType])
                }
                continuation.finish()
            }
        }
    }

    @MainActor
    public func writeTransaction<R>(callback: @escaping () async throws -> R) async throws -> R {
        return try await kotlinDatabase.readTransaction(callback: SuspendTaskWrapper {
            return try await callback()
        }) as! R
    }

    public func readTransaction<R>(callback: @escaping () async throws -> R) async throws -> R {
        return try await kotlinDatabase.readTransaction(callback: SuspendTaskWrapper {
            return try await callback()
        }) as! R
    }
}

enum PowerSyncError: Error {
    case invalidTransaction
    case invalidCredentials
    case issueFetchingCredentials
}

@MainActor
class SuspendTaskWrapper: KotlinSuspendFunction1 {
    let handle: () async throws -> Any

    init(_ handle: @escaping () async throws -> Any) {
        self.handle = handle
        print("🧵 SuspendTaskWrapper initialized on thread: \(Thread.current)")
    }

    
    nonisolated func __invoke(p1: Any?, completionHandler: @escaping (Any?, Error?) -> Void) {
        DispatchQueue.main.async {
            print("🧵 __invoke called on thread: \(Thread.current)")
            
            // Use specific dispatcher/actor if needed
            Task { @MainActor in
                print("🧵 Task started on thread: \(Thread.current)")
                do {
                    let result = try await self.handle()
                    print("🧵 Handle completed on thread: \(Thread.current)")
                    completionHandler(result, nil)
                } catch {
                    print("❌ Error on thread: \(Thread.current)")
                    debugPrint("Error: \(error)")
                    completionHandler(nil, error)
                }
                print("🧵 Task completed on thread: \(Thread.current)")
            }
        }
    }
}

//class SuspendTaskWrapper: KotlinSuspendFunction1 {
//    let handle: () async throws -> Any
//
//    init(_ handle: @escaping () async throws -> Any) {
//        self.handle = handle
//    }
//
//    func __invoke(p1: Any?, completionHandler: @escaping (Any?, Error?) -> Void) {
//        Task {
//            do {
//                let result = try await self.handle()
//                completionHandler(result, nil)
//            } catch {
//                debugPrint("Error: \(error)")
//                completionHandler(nil, error)
//            }
//        }
//    }
//}

extension CrudEntry {
    static func fromKotlin(_ kotlinEntry: PowerSync.CrudEntry) -> CrudEntry {
        return CrudEntry(
            id: kotlinEntry.id,
            clientId: Int(kotlinEntry.clientId),
            op: UpdateType.fromKotlin(kotlinEntry.op),
            table: kotlinEntry.table,
            transactionId: kotlinEntry.transactionId.map { Int(truncating: $0) },
            opData: kotlinEntry.opData.map { dict in
                dict.mapValues { value in
                    value as? String
                }
            }
        )
    }
}

extension UpdateType {
    static func fromKotlin(_ kotlinType: PowerSync.UpdateType) -> UpdateType {
        switch kotlinType {
        case .put: return .put
        case .patch: return .patch
        case .delete: return .delete
        }
    }
}

extension CrudTransaction {
    static func fromKotlin(_ kotlinTransaction: PowerSync.CrudTransaction) -> CrudTransaction {
        return CrudTransaction(
            transactionId: kotlinTransaction.transactionId.map { Int(truncating: $0) },
            crud: kotlinTransaction.crud.map { CrudEntry.fromKotlin($0) },
            complete: { checkpoint in
                    _ = try await kotlinTransaction.complete.invoke(p1: checkpoint)
            }
        )
    }
}

extension CrudBatch {
    static func fromKotlin(_ kotlinBatch: PowerSync.CrudBatch) -> CrudBatch {
        return CrudBatch(
            crud: kotlinBatch.crud.map { CrudEntry.fromKotlin($0) },
            hasMore: kotlinBatch.hasMore,
            complete: { checkpoint in
                    _ = try await kotlinBatch.complete.invoke(p1: checkpoint)
            }
        )
    }
}
