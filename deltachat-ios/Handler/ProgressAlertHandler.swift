import UIKit

protocol ProgressAlertHandler: UIViewController {
    var progressAlert: UIAlertController { get }
    var configureProgressObserver: Any? { get set }
    var onProgressSuccess: VoidFunction? { get set }
    func showProgressAlert(title: String)
    func updateProgressAlertValue(value: Int?)
    func updateProgressAlert(error: String?)
    func updateProgressAlertSuccess(completion: VoidFunction?)
    func addProgressAlertListener(onSuccess: @escaping VoidFunction)
}

extension ProgressAlertHandler {

    func showProgressAlert(title: String) {
        progressAlert.actions[0].isEnabled = true
        progressAlert.title = title
        progressAlert.message = String.localized("one_moment")
        present(progressAlert, animated: true, completion: nil)
    }

    func updateProgressAlertValue(value: Int?) {
        if let value = value {
            progressAlert.message = String.localized("one_moment") + " " + String(value/10) + "%"
        }
    }

    func updateProgressAlert(error message: String?) {
        DispatchQueue.main.async(execute: {
            self.progressAlert.dismiss(animated: false)
            let errorAlert = UIAlertController(title: String.localized("error"), message: message, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            self.present(errorAlert, animated: true, completion: nil)
        })
    }

    func updateProgressAlertSuccess(completion onComplete: VoidFunction?) {
        updateProgressAlertValue(value: 1000)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.progressAlert.dismiss(animated: true) {
                onComplete?()
            }
        })
    }

    func addProgressAlertListener(onSuccess: @escaping VoidFunction) {
        let nc = NotificationCenter.default
        configureProgressObserver = nc.addObserver(
            forName: dcNotificationConfigureProgress,
            object: nil,
            queue: nil
        ) { notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.updateProgressAlert(error: ui["errorMessage"] as? String)
                } else if ui["done"] as! Bool {
                    self.updateProgressAlertSuccess(completion: onSuccess)
                } else {
                    self.updateProgressAlertValue(value: ui["progress"] as? Int)
                }
            }
        }
    }
}

