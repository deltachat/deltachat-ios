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
    private var lastResponder: UIResponder?

    override func viewDidLoad() {
        lastResponder = UIResponder.currentFirstResponder
        super.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed, let lastResponder, let newFirstResponder = UIResponder.currentFirstResponder {
            if newFirstResponder != lastResponder {
                // Resigning here makes the animation smoother when we make lastResponder first responder again
                newFirstResponder.resignFirstResponder()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed, let lastResponder, !lastResponder.isFirstResponder {
            // I don't think this is perfect and it's definitely not how UIKit does it but it works.

            // - if the lastResponder failed to become first responder, and
            //   the next responder is not first responder
            // - try to make the next responder first responder
            // - if that fails try the next one
            // - if it succeeds try again from the start
            // This shouldn't get in a loop because if it finds a responder that
            // can become first responder it will only loop over the responders
            // up to the one that became first responder and if it doesn't find
            // any (more) it will set next to nil which will exit the loop.
            //
            // This is needed because lastResponder might not be on the screen (eg because
            // it is in an inputAccessoryView in which case the responder which owns the
            // inputAccessoryView needs to become first responder first)
            //
            // Note that UIResponder.canBecomeFirstResponder is not used because it
            // returns true in cases where becomeFirstResponder can still fail (eg the
            // case mentioned previously).
            var next = lastResponder.next
            while !lastResponder.becomeFirstResponder(),
                    let iterator = next, !iterator.isFirstResponder {
                // Failed to make lastResponder first responder so try the next one which
                // can cause the lastResponder to become available.
                if iterator.becomeFirstResponder() {
                    // next became first responder so try again
                    next = lastResponder.next
                } else {
                    next = next?.next
                }
            }
        }
    }
}

extension UIResponder {
    /// Finds the current first responder and returns it.
    ///
    /// If this gets rejected see https://stackoverflow.com/a/50472291/3393964 for alternatives.
    static var currentFirstResponder: UIResponder? {
        _currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(UIResponder.findFirstResponder(_:)), to: nil, from: nil, for: nil)
        return _currentFirstResponder
    }

    private static weak var _currentFirstResponder: UIResponder?

    @objc func findFirstResponder(_ sender: Any) {
        UIResponder._currentFirstResponder = self
    }
}
