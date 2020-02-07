import Foundation

/// assertion that is only checked in debug mode (if directly built from Xcode)
func safe_assert(_ condition: Bool, _ message: String? = nil) {
    #if DEBUG
    if let message = message {
        assert(condition, message)
    } else {
        assert(condition)
    }
    #endif
}

/// induces app crash only in debug mode (if directly built from Xcode)
func safe_fatalError(_ message: String? = nil) {
    #if DEBUG
    if let message = message {
        fatalError(message)
    } else {
        fatalError()
    }
    #endif
}
