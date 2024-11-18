import Foundation

/**
 * Abstract class to connect an app backend.
 *
 * The connector is responsible for:
 * 1. Creating credentials for connecting to the PowerSync service.
 * 2. Applying local changes against the backend application server.
 */
open class PowerSyncBackendConnector {
    private var cachedCredentials: PowerSyncCredentials?
    private var fetchOperation: Task<Void, Error>?
    
    public init() {
        self.cachedCredentials = nil
        self.fetchOperation = nil
    }
    
    /**
     * Get credentials current cached, or fetch new credentials if none are
     * available.
     *
     * These credentials may have expired already.
     */
    open func getCredentialsCached() async throws -> PowerSyncCredentials? {
        if let cached = cachedCredentials {
            return cached
        }
        
        do {
            try await prefetchCredentials()?.value
        } catch {
            throw PowerSyncError.issueFetchingCredentials
        }
        return cachedCredentials
    }
    
    /**
     * Immediately invalidate credentials.
     *
     * This may be called when the current credentials have expired.
     */
    open func invalidateCredentials() {
        cachedCredentials = nil
    }
    
    /**
     * Fetch a new set of credentials and cache it.
     *
     * Until this call succeeds, getCredentialsCached will still return the
     * old credentials.
     *
     * This may be called before the current credentials have expired.
     */
    open func prefetchCredentials() -> Task<Void, Error>? {
        // Cancel existing operation if it's still running
        if let existing = fetchOperation, !existing.isCancelled {
            return existing
        }
        
        let task = Task {
            let credentials = try await fetchCredentials()
            self.cachedCredentials = credentials
            self.fetchOperation = nil
        }
        
        fetchOperation = task
        return task
    }
    
    /**
     * Get credentials for PowerSync.
     *
     * This should always fetch a fresh set of credentials - don't use cached
     * values.
     *
     * Return nil if the user is not signed in. Throw an error if credentials
     * cannot be fetched due to a network error or other temporary error.
     *
     * This token is kept for the duration of a sync connection.
     */
    open func fetchCredentials() async throws -> PowerSyncCredentials? {
        fatalError("Subclasses must implement fetchCredentials()")
    }
    
    /**
     * Upload local changes to the app backend.
     *
     * Use PowerSyncDatabase.getCrudBatch to get a batch of changes to upload.
     *
     * Any thrown errors will result in a retry after the configured wait period (default: 5 seconds).
     */
    open func uploadData(database: PowerSyncDatabaseProtocol) async throws {
        fatalError("Subclasses must implement uploadData(database:)")
    }
}
