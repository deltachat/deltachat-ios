import UIKit
import DcCore

protocol ProgressAlertHandlerDataSource: AnyObject {
    func viewController() -> UIViewController
}

extension UIViewController: ProgressAlertHandlerDataSource {
    func viewController() -> UIViewController {
        self
    }
}

class ProgressAlertHandler {

    private let dcAccounts: DcAccounts
    weak var dataSource: ProgressAlertHandlerDataSource?
    private var onSuccess: (() -> Void)?
    private let checkForInternetConnectivity: Bool
    private var progressAlertController: UIAlertController?

    /// Use this is you want to handle notifications yourself.
    /// This way you can just use the alert-handler for the alert-part and it's not updating itself.
    init(dcAccounts: DcAccounts, onSuccess: (() -> Void)? = nil) {
        self.dcAccounts = dcAccounts
        self.checkForInternetConnectivity = false
    }

    init(dcAccounts: DcAccounts, notification: Notification.Name, checkForInternetConnectivity: Bool = false, onSuccess: (() -> Void)? = nil) {
        self.dcAccounts = dcAccounts
        self.onSuccess = onSuccess
        self.checkForInternetConnectivity = checkForInternetConnectivity

        NotificationCenter.default.addObserver(self, selector: #selector(Self.handleNotification(_:)), name: notification, object: nil)
    }

    @objc private func handleNotification(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }

        if ui["error"] as? Bool ?? false {
            dcAccounts.startIo()

            var errorMessage: String? = ui["errorMessage"] as? String
            // override if we need to check for connectiviy issues
            if checkForInternetConnectivity,
               let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let reachability = appDelegate.reachability,
               reachability.connection == .unavailable {
                errorMessage = String.localized("login_error_no_internet_connection")
            }

            self.updateProgressAlert(error: errorMessage)
        } else if ui["done"] as? Bool ?? false {
            dcAccounts.startIo()
            self.updateProgressAlertSuccess(completion: onSuccess)
        } else {
            self.updateProgressAlertValue(value: ui["progress"] as? Int)
        }
    }

    public func updateProgressAlertValue(value: Int?) {
        guard let value else { return }
        guard let progressAlertController else { return assertionFailure("Please present an alert") }

        progressAlertController.message = String.localized("one_moment") + " " + String(value/10) + "%"
    }

    public func updateProgressAlert(message: String) {
        guard let progressAlertController else { return assertionFailure("Please present an alert") }

        progressAlertController.message = message
    }

    public func updateProgressAlert(error message: String?, completion onComplete: (() -> Void)? = nil) {
        guard let progressAlertController else { return assertionFailure("Please present an alert") }
        guard let dataSource else { return assertionFailure("No DataSource") }

        // CAVE: show the new alert in the dismiss-done-handler of the previous one -
        // otherwise we get the error "Attempt to present <UIAlertController: ...> while a presentation is in progress."
        // and the error won't be shown.
        // (when animated is true, that works also sequentially, however better not rely on that, also we do not want an animation here)
        progressAlertController.dismiss(animated: false) {
            let errorAlert = UIAlertController(title: String.localized("error"), message: message, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                onComplete?()
            }))
            // sometimes error messages are not shown and we get the same error as above
            // as a workaround we disable animated here as well
            dataSource.viewController().present(errorAlert, animated: false, completion: nil)
        }
    }

    public func updateProgressAlertSuccess(completion onComplete: VoidFunction?) {        
        guard let progressAlertController else { return assertionFailure("Please present an alert") }

        updateProgressAlertValue(value: 1000)
        // delay so the user has time to read the success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            progressAlertController.dismiss(animated: true) {
                onComplete?()
            }
        })
    }

    public func showProgressAlert(title: String, dcContext: DcContext) {
        guard let dataSource else { return assertionFailure("No DataSource") }

        let progressAlertController = UIAlertController(title: title, message: String.localized("one_moment"), preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: String.localized("cancel"),
                                         style: .cancel,
                                         handler: { _ in
            dcContext.stopOngoingProcess()
        })
        progressAlertController.addAction(cancelAction)

        dataSource.viewController().present(progressAlertController, animated: true, completion: nil)
        self.progressAlertController = progressAlertController
    }
}
