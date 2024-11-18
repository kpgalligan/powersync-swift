import Foundation

struct OplogEntry: Codable, Equatable {
    let checksum: Int64
    let opId: String
    let rowId: String?
    let rowType: String?
    let op: OpType.RawValue?
    let subkey: String?
    let data: String?

    enum CodingKeys: String, CodingKey {
        case checksum
        case opId = "op_id"
        case rowId = "object_id"
        case rowType = "object_type"
        case op
        case subkey
        case data
    }

    init(
        checksum: Int64,
        opId: String,
        rowId: String? = nil,
        rowType: String? = nil,
        op: OpType.RawValue? = nil,
        subkey: String? = nil,
        data: String? = nil
    ) {
        self.checksum = checksum
        self.opId = opId
        self.rowId = rowId
        self.rowType = rowType
        self.op = op
        self.subkey = subkey
        self.data = data
    }
}
