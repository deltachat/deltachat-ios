import UIKit

/// https://gist.github.com/Amzd/223979ef5a06d98ef17d2d78dbd96e22
extension UIViewController {
    /// UIDocumentPickerViewController by itself does not return first responder to the view controller that presented it
    /// when the cancel button is pressed after the search field was used. This function fixes that by making the previous
    /// first responder, first responder again when the document picker is dismissed.
    /// Normally this is handled by the private `UIViewController._restoreInputViewsForPresentation`
    /// but for some reason the UIDocumentPickerViewController does not call that, and since it's closed source I don't
    /// know why.
    ///
    /// To confirm this:
    /// - have a viewcontroller with a textfield
    /// - press on textfield so it is firstResponder
    /// - present any other vc with a textfield
    /// - press new textfield
    /// - dismiss new vc
    /// - now the original textfield automatically becomes first responder again
    /// - present UIDocumentPickerViewController
    /// - press search textfield
    /// - dismiss with the cancel button
    /// - original textfield does not automatically become first responder again (without this function)
    public func present(_ documentPicker: UIDocumentPickerViewController, animated: Bool, completion: (() -> Void)? = nil) {
        // In iOS 17 and iOS 16 the UIDocumentPickerViewController does not
        // give back the first responder when search was used
        if #available(iOS 16, *) {
            documentPicker.returnFirstRespondersOnDismiss()
        }
        present(documentPicker as UIViewController, animated: animated, completion: completion)
    }

    /// In iOS 16 and below and iOS 18 the UIImagePickerController does not give back the first responder when search was used.
    /// This function fixes that by making the previous first responder, first responder again when the image picker is dismissed.
    public func present(_ imagePicker: UIImagePickerController, animated: Bool, completion: (() -> Void)? = nil) {
        if #unavailable(iOS 17) { // pre iOS 17
            imagePicker.returnFirstRespondersOnDismiss()
        } else if #available(iOS 18, *) { // iOS 18 and up
            imagePicker.returnFirstRespondersOnDismiss()
        }
        present(imagePicker as UIViewController, animated: animated, completion: completion)
    }
}

private var lastRespondersKey: UInt8 = 0
extension UIViewController {
    /// Resigns first responders when called and returns first responders when this view is dismissed. Call before presenting.
    fileprivate func returnFirstRespondersOnDismiss() {
        Self.swizzleOnce()
        while let next = UIResponder.currentFirstResponder, next.resignFirstResponder() {
            self.lastResponders.append(next)
        }
    }

    fileprivate var lastResponders: [UIResponder] {
        get { objc_getAssociatedObject(self, &lastRespondersKey) as? [UIResponder] ?? [] }
        /// Filter for self because that could create a reference cycle
        set { objc_setAssociatedObject(self, &lastRespondersKey, newValue.filter { $0 !== self }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)}
    }

    private var selfOrParentIsBeingDismissed: Bool {
        parent?.isBeingDismissed ?? isBeingDismissed || isBeingDismissed
    }

    @objc fileprivate func _viewWillDisappear(_ animated: Bool) {
        _viewWillDisappear(animated)
        if selfOrParentIsBeingDismissed, !lastResponders.isEmpty, let newFirstResponder = UIResponder.currentFirstResponder {
            // Resigning here makes the animation smoother when we make lastResponders first responder again
            newFirstResponder.resignFirstResponder()
        }
    }

    @objc fileprivate func _viewDidDisappear(_ animated: Bool) {
        _viewDidDisappear(animated)
        if selfOrParentIsBeingDismissed, !lastResponders.isEmpty {
            lastResponders.reversed().forEach { $0.becomeFirstResponder() }
            lastResponders = []
        }
    }

    fileprivate static func swizzleOnce() { return _swizzle }
    private static var _swizzle: Void = {
        if let originalWillMethod = class_getInstanceMethod(UIViewController.self, #selector(viewWillDisappear)),
           let swizzledWillMethod = class_getInstanceMethod(UIViewController.self, #selector(_viewWillDisappear)) {
            method_exchangeImplementations(originalWillMethod, swizzledWillMethod)
        }
        if let originalDidMethod = class_getInstanceMethod(UIViewController.self, #selector(viewDidDisappear)),
           let swizzledDidMethod = class_getInstanceMethod(UIViewController.self, #selector(_viewDidDisappear)) {
            method_exchangeImplementations(originalDidMethod, swizzledDidMethod)
        }
    }()
}

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
