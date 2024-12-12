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
            let vc = GiveBackMyFirstResponder(culprit: documentPicker)
            present(vc, animated: animated, completion: completion)
        } else {
            present(documentPicker as UIViewController, animated: animated, completion: completion)
        }
    }

    /// In iOS 16 and below the UIImagePickerController does not give back the first responder when search was used.
    /// This function fixes that by making the previous first responder, first responder again when the image picker is dismissed.
    public func present(_ imagePicker: UIImagePickerController, animated: Bool, completion: (() -> Void)? = nil) {
        if #available(iOS 17, *) {
            present(imagePicker as UIViewController, animated: animated, completion: completion)
        } else {
            let vc = GiveBackMyFirstResponder(culprit: imagePicker)
            present(vc, animated: animated, completion: completion)
        }
    }
}

private class GiveBackMyFirstResponder<VC: UIViewController>: FirstResponderReturningViewController {
    @MainActor var culprit: VC

    @MainActor init(culprit: VC) {
        self.culprit = culprit
        super.init(nibName: nil, bundle: nil)
    }

    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(culprit)
        culprit.view.frame = view.frame
        view.addSubview(culprit.view)
        culprit.didMove(toParent: self)
    }
}

private class FirstResponderReturningViewController: UIViewController {
    private var lastResponders: [UIResponder] = {
        var lastResponders: [UIResponder] = []
        while let next = UIResponder.currentFirstResponder, next.resignFirstResponder() {
            lastResponders.append(next)
        }
        return lastResponders
    }()

    override var isBeingDismissed: Bool {
        parent?.isBeingDismissed ?? super.isBeingDismissed || super.isBeingDismissed
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed, !lastResponders.isEmpty, let newFirstResponder = UIResponder.currentFirstResponder {
            // Resigning here makes the animation smoother when we make lastResponders first responder again
            newFirstResponder.resignFirstResponder()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed, !lastResponders.isEmpty {
            lastResponders.reversed().forEach { $0.becomeFirstResponder() }
        }
    }
}


extension UIResponder {
    /// Note: Do not replace this with the `UIApplication.shared.sendAction(_, to: nil, from: nil, for: nil)` method
    /// because that does not work reliably in all cases. eg, when you initialise a UIImagePickerController on iOS 16 it returns nil even if your textfield is still first responder.
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
