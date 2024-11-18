import Foundation

enum OpType: Int, Codable {
    case clear = 1
    case move = 2
    case put = 3
    case remove = 4
}

extension OpType: CustomStringConvertible {
    var description: String {
        return "\(self.rawValue)"
    }
}
