import UIKit

/// https://gist.github.com/Amzd/c3171021488fc82d1b68cfd8e89ada7b
extension UIStatusBarManager {
    public static var statusBarTappedNotification: Notification.Name = {
        if let originalMethod = class_getInstanceMethod(UIStatusBarManager.self, Selector(("handleTapAction:"))),
           let swizzledMethod = class_getInstanceMethod(UIStatusBarManager.self, #selector(_handleTapAction)),
           // Prevent crash in case an argument is added/removed in the future
           method_getNumberOfArguments(originalMethod) == method_getNumberOfArguments(swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        return .init("statusBarSelected")
    }()

    @objc private func _handleTapAction(_ sender: Any?) {
         _handleTapAction(sender) // Call the original implementation
        NotificationCenter.default.post(name: UIStatusBarManager.statusBarTappedNotification, object: nil)
    }
}
