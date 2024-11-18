import Foundation
import Combine

/// Protocol defining the sync status interface
public protocol SyncStatusData {
    /// true if currently connected.
    ///
    /// This means the PowerSync connection is ready to download, and PowerSyncBackendConnector.uploadData may be called for any local changes.
    var connected: Bool { get }
    
    /// true if the PowerSync connection is busy connecting.
    ///
    /// During this stage, PowerSyncBackendConnector.uploadData may already be called, and uploading may be true.
    var connecting: Bool { get }
    
    /// true if actively downloading changes.
    ///
    /// This is only true when connected is also true.
    var downloading: Bool { get }
    
    /// true if uploading changes
    var uploading: Bool { get }
    
    /// Time that a last sync has fully completed, if any.
    ///
    /// Currently this is reset to null after a restart.
    var lastSyncedAt: Date? { get }
    
    /// Indicates whether there has been at least one full sync, if any.
    ///
    /// Is nil when unknown, for example when state is still being loaded from the database.
    var hasSynced: Bool? { get }
    
    /// Error during uploading.
    ///
    /// Cleared on the next successful upload.
    var uploadError: Any? { get }
    
    /// Error during downloading (including connecting).
    ///
    /// Cleared on the next successful data download.
    var downloadError: Any? { get }
    
    /// Convenience getter for either the value of downloadError or uploadError
    var anyError: Any? { get }
}

/// Internal container for sync status data
struct SyncStatusDataContainer: SyncStatusData {
    let connected: Bool
    let connecting: Bool
    let downloading: Bool
    let uploading: Bool
    let lastSyncedAt: Date?
    let hasSynced: Bool?
    let uploadError: Any?
    let downloadError: Any?
    
    var anyError: Any? {
        return downloadError ?? uploadError
    }
    
    init(
        connected: Bool = false,
        connecting: Bool = false,
        downloading: Bool = false,
        uploading: Bool = false,
        lastSyncedAt: Date? = nil,
        hasSynced: Bool? = nil,
        uploadError: Any? = nil,
        downloadError: Any? = nil
    ) {
        self.connected = connected
        self.connecting = connecting
        self.downloading = downloading
        self.uploading = uploading
        self.lastSyncedAt = lastSyncedAt
        self.hasSynced = hasSynced
        self.uploadError = uploadError
        self.downloadError = downloadError
    }
}

/// Public sync status class
public class SyncStatus: SyncStatusData {
    private var data: SyncStatusDataContainer
    private let stateSubject: CurrentValueSubject<SyncStatusDataContainer, Never>
    
    init(data: SyncStatusDataContainer = SyncStatusDataContainer()) {
        self.data = data
        self.stateSubject = CurrentValueSubject(data)
    }
    
    /// Returns a publisher which emits whenever the sync status has changed
    public func asPublisher() -> AnyPublisher<SyncStatusData, Never> {
        return stateSubject
            .map { $0 as SyncStatusData }
            .eraseToAnyPublisher()
    }
    
    /// Updates the internal sync status indicators and emits publisher updates
    internal func update(
        connected: Bool? = nil,
        connecting: Bool? = nil,
        downloading: Bool? = nil,
        uploading: Bool? = nil,
        hasSynced: Bool? = nil,
        lastSyncedAt: Date? = nil,
        uploadError: Any? = nil,
        downloadError: Any? = nil,
        clearUploadError: Bool = false,
        clearDownloadError: Bool = false
    ) {
        data = SyncStatusDataContainer(
            connected: connected ?? data.connected,
            connecting: connecting ?? data.connecting,
            downloading: downloading ?? data.downloading,
            uploading: uploading ?? data.uploading,
            lastSyncedAt: lastSyncedAt ?? data.lastSyncedAt,
            hasSynced: hasSynced ?? data.hasSynced,
            uploadError: clearUploadError ? nil : (uploadError ?? data.uploadError),
            downloadError: clearDownloadError ? nil : (downloadError ?? data.downloadError)
        )
        stateSubject.send(data)
    }
    
    public var connected: Bool { data.connected }
    public var connecting: Bool { data.connecting }
    public var downloading: Bool { data.downloading }
    public var uploading: Bool { data.uploading }
    public var lastSyncedAt: Date? { data.lastSyncedAt }
    public var hasSynced: Bool? { data.hasSynced }
    public var uploadError: Any? { data.uploadError }
    public var downloadError: Any? { data.downloadError }
    public var anyError: Any? { data.anyError }
    
    public var description: String {
        return "SyncStatus(connected=\(connected), connecting=\(connecting), downloading=\(downloading), uploading=\(uploading), lastSyncedAt=\(String(describing: lastSyncedAt)), hasSynced=\(String(describing: hasSynced)), error=\(String(describing: anyError)))"
    }
    
    /// Creates an empty sync status instance
    public static func empty() -> SyncStatus {
        return SyncStatus()
    }
}
