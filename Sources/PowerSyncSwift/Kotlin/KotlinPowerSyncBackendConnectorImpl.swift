import Foundation
import PowerSync

//open class KotlinPowerSyncBackendConnectorImpl: KotlinPowerSyncBackendConnector {
//    open func internalFetchCredentials() async throws -> PowerSyncCredentials? {
//        fatalError("Subclasses must implement fetchCredentials()")
//    }
//    
//    public override func __fetchCredentials() async throws -> KotlinPowerSyncCredentials? {
//        return try await self.internalFetchCredentials()?.kotlinCredentials
//    }
//    
//    /// Upload local changes to the app backend
//    open func internalUploadData(database: KotlinPowerSyncDatabase) async throws {
//        fatalError("Subclasses must implement uploadData()")
//    }
//    
//    open func uploadData(database: KotlinPowerSyncDatabase) async throws {
//        _ = try await self.internalUploadData(database: database)
//    }
//}
