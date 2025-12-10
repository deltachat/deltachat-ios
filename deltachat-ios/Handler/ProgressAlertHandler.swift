import UIKit
import DcCore

class ProgressAlertHandler {
    weak var dataSource: UIViewController?
    var cancelled: Bool = false
    private var onSuccess: (() -> Void)?
    private let checkForInternetConnectivity: Bool
    private var progressAlertController: UIAlertController?
    private var lastErrorPara: String = ""

    /// Use this is you want to handle notifications yourself.
    /// This way you can just use the alert-handler for the alert-part and it's not updating itself.
    init() {
        self.checkForInternetConnectivity = false
    }

    init(notification: Notification.Name, checkForInternetConnectivity: Bool = false, onSuccess: (() -> Void)? = nil) {
        self.onSuccess = onSuccess
        self.checkForInternetConnectivity = checkForInternetConnectivity

        NotificationCenter.default.addObserver(self, selector: #selector(Self.handleNotification(_:)), name: notification, object: nil)
    }

    @objc private func handleNotification(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }

        DispatchQueue.main.async { [weak self] in

            guard let self else { return }

            if ui["error"] as? Bool ?? false {
                DcAccounts.shared.startIo()

                var errorMessage: String = ui["errorMessage"] as? String ?? "ErrString"
                // override if we need to check for connectiviy issues
                if checkForInternetConnectivity,
                   let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                   let reachability = appDelegate.reachability,
                   reachability.connection == .unavailable {
                    errorMessage = String.localized("login_error_no_internet_connection")
                }
                
                self.updateProgressAlert(error: errorMessage)
            } else if ui["done"] as? Bool ?? false {
                DcAccounts.shared.startIo()
                self.updateProgressAlertSuccess(completion: onSuccess)
            } else {
                self.updateProgressAlertValue(value: ui["progress"] as? Int)
            }
        }
    }

    public func updateProgressAlertValue(value: Int?) {
        guard let value else { return }
        guard let progressAlertController else { return assertionFailure("Please present an alert") }

        progressAlertController.message = String.localized("one_moment") + " " + String(value/10) + "%" + lastErrorPara
    }

    public func updateProgressAlert(message: String) {
        guard let progressAlertController else { return assertionFailure("Please present an alert") }

        progressAlertController.message = message + lastErrorPara
    }

    public func updateProgressAlert(error: String) {
        logger.error(error)
        guard let progressAlertController else { return assertionFailure("Please present an alert") }
        progressAlertController.message = error
        lastErrorPara = "\n\n" + error
    }

    public func updateProgressAlertSuccess(completion onComplete: VoidFunction? = nil) {
        guard let progressAlertController else { return assertionFailure("Please present an alert") }

        updateProgressAlertValue(value: 1000)
        // delay so the user has time to read the success message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            progressAlertController.dismiss(animated: true) {
                onComplete?()
            }
        })
    }

    public func showProgressAlert(title: String?, dcContext: DcContext) {
        guard let dataSource else { return assertionFailure("No DataSource") }

        let progressAlertController = UIAlertController(title: title, message: String.localized("one_moment"), preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { [weak self] _ in
            self?.cancelled = true
            dcContext.stopOngoingProcess()
        })
        progressAlertController.addAction(cancelAction)

        dataSource.present(progressAlertController, animated: true, completion: nil)
        self.progressAlertController = progressAlertController
    }
}
