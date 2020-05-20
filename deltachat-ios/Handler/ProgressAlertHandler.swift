import UIKit
import DcCore

protocol ProgressAlertHandler: UIViewController {
    var progressAlert: UIAlertController? { get set }   // needs to be implemented as weak
    var progressObserver: Any? { get set } // set to nil in viewDidDisappear
    func showProgressAlert(title: String, dcContext: DcContext)
    func updateProgressAlertValue(value: Int?)
    func updateProgressAlert(error: String?)
    func updateProgressAlertSuccess(completion: VoidFunction?)
    func addProgressAlertListener(progressName: Notification.Name, onSuccess: @escaping VoidFunction)
}

extension ProgressAlertHandler {

    func showProgressAlert(title: String, dcContext: DcContext) {
        self.progressAlert = makeProgressAlert(dcContext: dcContext)
        guard let progressAlert = progressAlert else { return }
        progressAlert.actions[0].isEnabled = true
        progressAlert.title = title
        progressAlert.message = String.localized("one_moment")
        present(progressAlert, animated: true, completion: nil)
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

    func updateProgressAlert(error message: String?) {
        DispatchQueue.main.async(execute: {
            self.progressAlert?.dismiss(animated: false)
            let errorAlert = UIAlertController(title: String.localized("error"), message: message, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            self.present(errorAlert, animated: true, completion: nil)
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

    func addProgressAlertListener(progressName: Notification.Name, onSuccess: @escaping VoidFunction) {
        let nc = NotificationCenter.default
        progressObserver = nc.addObserver(
            forName: progressName,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo {
                if ui["error"] as? Bool ?? false {
                    self.updateProgressAlert(error: ui["errorMessage"] as? String)
                } else if ui["done"] as? Bool ?? false {
                    self.updateProgressAlertSuccess(completion: onSuccess)
                } else {
                    self.updateProgressAlertValue(value: ui["progress"] as? Int)
                }
            }
        }
    }
}
