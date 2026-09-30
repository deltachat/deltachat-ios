import UIKit

extension UIResponder {
    /// Note: Do not replace this with the `UIApplication.shared.sendAction(_, to: nil, from: nil, for: nil)` method
    /// because that does not work reliably in all cases. eg, when you initialise a UIImagePickerController on iOS 16 `sendAction` returns nil even if your textfield is still first responder.
    static var currentFirstResponder: UIResponder? {
        for window in UIApplication.shared.windows {
            if let firstResponder = window.previousFirstResponder {
                return firstResponder
            }
        }
        return nil
    }
}

extension UIResponder {
    var nextFirstResponder: UIResponder? {
        return isFirstResponder ? self : next?.nextFirstResponder
    }
}

extension UIView {
    var previousFirstResponder: UIResponder? {
        return nextFirstResponder ?? subviews.compactMap { $0.previousFirstResponder }.first
    }
}
