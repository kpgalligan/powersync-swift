import Foundation
import Alamofire

class PowerSyncNetworkClient {
    private let session: Session
    private let connector: PowerSyncBackendConnector
    
    init(connector: PowerSyncBackendConnector) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval.infinity
        self.session = Session(configuration: configuration)
        self.connector = connector
    }
    
    func streamSync(request: StreamingSyncRequest) async throws -> AsyncThrowingStream<String, Error> {
        guard let credentials = try await connector.getCredentialsCached() else {
            throw PowerSyncError.invalidCredentials
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                let uri = credentials.endpointUri(path: "sync/stream")
                let request = session.streamRequest(
                    uri,
                    method: .post,
                    parameters: request,
                    encoder: JSONParameterEncoder.default,
                    headers: self.createHeaders(with: credentials)
                )
                
                request.responseStreamString { [weak self] stream in
                    guard let self = self else { return }
                    
                    switch stream.event {
                    case .stream(let result):
                        switch result {
                        case .success(let string):
                            continuation.yield(string)
                        case .failure(let error):
                            self.handleNetworkError(error)
                            continuation.finish(throwing: error)
                        }
                    case .complete(let completion):
                        if let error = completion.error {
                            self.handleNetworkError(error)
                            continuation.finish(throwing: error)
                        } else {
                            continuation.finish()
                        }
                    }
                }
            }
        }
    }
    
    func getWriteCheckpoint(clientId: String) async throws -> String {
        guard let credentials = try await connector.getCredentialsCached() else {
            throw PowerSyncError.invalidCredentials
        }
        
        let uri = credentials.endpointUri(path: "write-checkpoint2.json?client_id=\(clientId)")
        
        let response = try await session.request(
            uri,
            headers: createHeaders(with: credentials)
        ).serializingDecodable(WriteCheckpointResponse.self).value
        
        return response.data.writeCheckpoint
    }
    
    private func createHeaders(with credentials: PowerSyncCredentials) -> HTTPHeaders {
        return [
            "Authorization": "Token \(credentials.token)",
            "User-Id": credentials.userId ?? "",
            "Content-Type": "application/json"
        ]
    }
    
    private func handleNetworkError(_ error: Error) {
        if let afError = error as? AFError,
           let response = afError.responseCode,
           response == 401 {
            connector.invalidateCredentials()
        }
    }
}
