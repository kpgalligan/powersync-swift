enum InternalTable: String, CustomStringConvertible {
    case data = "ps_data"
    case crud = "ps_crud"
    case buckets = "ps_buckets"
    case oplog = "ps_oplog"
    case untyped = "ps_untyped"
    
    // This computed property will always return the raw value
    var description: String {
        return self.rawValue
    }
}
