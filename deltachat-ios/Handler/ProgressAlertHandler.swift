import UIKit
import DcCore

protocol ProgressAlertHandlerDataSource: AnyObject {
    func viewController() -> UIViewController
}

class ProgressAlertHandler {

    let dcAccounts: DcAccounts
    weak var dataSource: ProgressAlertHandlerDataSource

    // add Completion block
    init(dcAccounts: DcAccounts, notification: Notification.Name) {
        self.dcAccounts = dcAccounts

        NotificationCenter.default.addObserver(self, selector: #selector(Self.handleNotification(_:)), name: notification, object: nil)
    }

    @objc private func handleNotification(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }

        if ui["error"] as? Bool ?? false {
            dcAccounts.startIo()
            self.updateProgressAlert(error: ui["errorMessage"] as? String)
        } else if ui["done"] as? Bool ?? false {
            dcAccounts.startIo()
//            self.updateProgressAlertSuccess(completion: onSuccess)
        } else {
//            self.updateProgressAlertValue(value: ui["progress"] as? Int)
        }
    }
}
