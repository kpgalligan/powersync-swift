import Foundation

/// Type of local change.
public enum UpdateType {
    /// Insert or replace a row. All non-null columns are included in the data.
    case put
    
    /// Update a row if it exists. All updated columns are included in the data.
    case patch
    
    /// Delete a row if it exists.
    case delete
    
    /// The JSON string representation of the update type
    private var json: String {
        switch self {
        case .put: return "PUT"
        case .patch: return "PATCH"
        case .delete: return "DELETE"
        }
    }
    
    /// Convert the update type to its JSON string representation
    public func toJSON() -> String {
        return json
    }
    
    /// Create an UpdateType from a JSON string, returning nil if the string doesn't match any known type
    public static func fromJSON(_ json: String) -> UpdateType? {
        switch json {
        case "PUT": return .put
        case "PATCH": return .patch
        case "DELETE": return .delete
        default: return nil
        }
    }
}
