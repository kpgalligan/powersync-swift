import Foundation

actor SharedPendingDeletesActor {
    private(set) var pendingBucketDeletes: Bool
    
    init(initialValue: Bool = false) {
        self.pendingBucketDeletes = initialValue
    }
    
    func setPendingBucketDeletes(_ value: Bool) {
        pendingBucketDeletes = value
    }
    
    func getPendingBucketDeletes() -> Bool {
        return pendingBucketDeletes
    }
}
