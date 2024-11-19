//import Foundation
//
///**
// * Implement this to connect an app backend.
// *
// * The connector is responsible for:
// * 1. Creating credentials for connecting to the PowerSync service.
// * 2. Applying local changes against the backend application server.
// */
//open class PowerSyncBackendConnector: KotlinPowerSyncBackendConnectorImpl {
//    private var kotlinConnector: KotlinPowerSyncBackendConnectorImpl
//    
//    public override init() {
//        kotlinConnector = KotlinPowerSyncBackendConnectorImpl.init()
//    }
//
//    /// Get credentials from cache or fetch new ones if none are available
//    public func getCredentialsCachedSwift() async throws -> PowerSyncCredentials? {
//        let kotlinCreds = try await kotlinConnector.getCredentialsCached()
//        return kotlinCreds.map { PowerSyncCredentials(kotlin: $0) }
//    }
//    
//    /// Immediately invalidate current credentials
//    override public func invalidateCredentials() {
//        kotlinConnector.invalidateCredentials()
//    }
//    
//    /// Fetch a new set of credentials and cache them
//    public func prefetchCredentialsSwift() async {
//        _ = try? await kotlinConnector.prefetchCredentials()?.join()
//    }
//
//    open override func internalFetchCredentials() async throws -> PowerSyncCredentials? {
//        return try await fetchCredentials()
//    }
//    
//    /// Get fresh credentials for PowerSync
//    open func fetchCredentials() async throws -> PowerSyncCredentials? {
//        fatalError("Subclasses must implement fetchCredentials()")
//    }
//    
//    open override func internalUploadData(database: KotlinPowerSyncDatabase) async throws {
//        return try await uploadData(database: database.asKotlinDatabase())
//    }
//    
//    /// Upload local changes to the app backend
//    open func uploadData(database: KotlinPowerSyncDatabaseImpl) async throws {
//        fatalError("Subclasses must implement uploadData()")
//    }
//}
