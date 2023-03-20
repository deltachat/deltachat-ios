import UIKit
import DcCore

protocol ProgressAlertHandler: UIViewController {
    var progressAlert: UIAlertController? { get set }   // needs to be implemented as weak
    var progressObserver: NSObjectProtocol? { get set } // set to nil in viewDidDisappear
    func showProgressAlert(title: String, dcContext: DcContext)
    func updateProgressAlertValue(value: Int?)
    func updateProgressAlert(error: String?, completion: VoidFunction?)
    func updateProgressAlertSuccess(completion: VoidFunction?)
    func addProgressAlertListener(dcAccounts: DcAccounts, progressName: Notification.Name, onSuccess: @escaping VoidFunction)
}

extension ProgressAlertHandler {

    func showProgressAlert(title: String, dcContext: DcContext) {
        let progressAlert = makeProgressAlert(dcContext: dcContext)
        progressAlert.actions[0].isEnabled = true
        progressAlert.title = title
        progressAlert.message = String.localized("one_moment")
        self.present(progressAlert, animated: true, completion: nil)
        self.progressAlert = progressAlert
    }

    private func makeProgressAlert(dcContext: DcContext) -> UIAlertController {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: String.localized("cancel"),
            style: .cancel,
            handler: { _ in
                dcContext.stopOngoingProcess()
        }))
        return alert
    }

    func updateProgressAlertValue(value: Int?) {
        if let value = value {
            progressAlert?.message = String.localized("one_moment") + " " + String(value/10) + "%"
        }
    }

    func updateProgressAlert(message: String) {
        progressAlert?.message = message
    }

    func updateProgressAlert(error message: String?, completion onComplete: VoidFunction? = nil) {
        DispatchQueue.main.async(execute: {
            // CAVE: show the new alert in the dismiss-done-handler of the previous one -
            // otherwise we get the error "Attempt to present <UIAlertController: ...> while a presentation is in progress."
            // and the error won't be shown.
            // (when animated is true, that works also sequentially, however better not rely on that, also we do not want an animation here)
            self.progressAlert?.dismiss(animated: false) {
                let errorAlert = UIAlertController(title: String.localized("error"), message: message, preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                    onComplete?()
                }))
                // sometimes error messages are not shown and we get the same error as above
                // as a workaround we disable animated here as well
                self.present(errorAlert, animated: false, completion: nil)
            }
        })
    }

    func updateProgressAlertSuccess(completion onComplete: VoidFunction?) {
        updateProgressAlertValue(value: 1000)
        // delay so the user has time to read the success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.progressAlert?.dismiss(animated: true) {
                onComplete?()
            }
        })
    }

    func addProgressAlertListener(dcAccounts: DcAccounts, progressName: Notification.Name, onSuccess: @escaping VoidFunction) {
        let nc = NotificationCenter.default
        progressObserver = nc.addObserver(
            forName: progressName,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo {
                if ui["error"] as? Bool ?? false {
                    dcAccounts.startIo()
                    self.updateProgressAlert(error: ui["errorMessage"] as? String)
                } else if ui["done"] as? Bool ?? false {
                    dcAccounts.startIo()
                    self.updateProgressAlertSuccess(completion: onSuccess)
                } else {
                    self.updateProgressAlertValue(value: ui["progress"] as? Int)
                }
            }
        }
    }
}
