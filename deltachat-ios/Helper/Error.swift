import UIKit

/// dc_assert is only exectued in debug mode (when executed from xcode).
func dc_assert(_ condition: Bool, _ message: String? = nil, presenter: UIViewController? = nil) {
    #if DEBUG
    if !condition, let presenter = presenter {
        let alert = UIAlertController(title: "Congratulation! You found an assertion.", message: message, preferredStyle: .alert)
        presenter.present(alert, animated: false, completion: nil)
    }
    if let message = message {
        assert(condition, message)
    } else {
        assert(condition)
    }
    #endif
}

/// dc_fatal_error is only exectued in debug mode (when executed from xcode).
func dc_fatalError(_ message: String? = nil) {
    #if DEBUG
    if let message = message {
        fatalError(message)
    } else {
        fatalError()
    }
    #endif
}
