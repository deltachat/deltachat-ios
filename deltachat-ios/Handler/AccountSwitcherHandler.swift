import Foundation
import UIKit
import DcCore
import DBDebugToolkit
import Intents

protocol AccountSwitcherHandler: UIViewController {
    var dcAccounts: DcAccounts { get }
    func showSwitchAccountMenu()
}

extension AccountSwitcherHandler {
    func showSwitchAccountMenu() {
        let accountIds = dcAccounts.getAll()
        let selectedAccountId = dcAccounts.getSelected().id
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let prefs = UserDefaults.standard
        // switch account
        let menu = UIAlertController(title: String.localized("switch_account"), message: nil, preferredStyle: .safeActionSheet)
        for accountId in accountIds {
            let account = dcAccounts.get(id: accountId)
            let newMessages = account.getFreshMessages().count
            let messageBadge = newMessages == 0 ? "" : " [" + String(newMessages) + "]"
            
            var title = account.displaynameAndAddr
            title = (selectedAccountId==accountId ? "✔︎ " : "") + title + messageBadge
            menu.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                prefs.setValue(selectedAccountId, forKey: Constants.Keys.lastSelectedAccountKey)
                _ = self.dcAccounts.select(id: accountId)
                appDelegate.reloadDcContext()
            }))
        }

        // add account
        menu.addAction(UIAlertAction(title: String.localized("add_account"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            prefs.setValue(selectedAccountId, forKey: Constants.Keys.lastSelectedAccountKey)
            _ = self.dcAccounts.add()
            appDelegate.reloadDcContext()
        }))

        // delete account
        menu.addAction(UIAlertAction(title: String.localized("delete_account"), style: .destructive, handler: { [weak self] _ in
            let confirm1 = UIAlertController(title: String.localized("delete_account_ask"), message: nil, preferredStyle: .safeActionSheet)
            confirm1.addAction(UIAlertAction(title: String.localized("delete_account"), style: .destructive, handler: { [weak self] _ in
                guard let self = self else { return }
                let account = self.dcAccounts.get(id: selectedAccountId)
                let confirm2 = UIAlertController(title: account.displaynameAndAddr,
                    message: String.localized("forget_login_confirmation_desktop"), preferredStyle: .alert)
                confirm2.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { [weak self] _ in
                    guard let self = self else { return }
                    appDelegate.locationManager.disableLocationStreamingInAllChats()
                    _ = self.dcAccounts.remove(id: selectedAccountId)
                    KeychainManager.deleteAccountSecret(id: selectedAccountId)
                    INInteraction.delete(with: "\(selectedAccountId)", completion: nil)
                    if self.dcAccounts.getAll().isEmpty {
                        _ = self.dcAccounts.add()
                    } else {
                        let lastSelectedAccountId = prefs.integer(forKey: Constants.Keys.lastSelectedAccountKey)
                        if lastSelectedAccountId != 0 {
                            _ = self.dcAccounts.select(id: lastSelectedAccountId)
                        }
                    }
                    appDelegate.reloadDcContext()
                }))
                confirm2.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
                self.present(confirm2, animated: true, completion: nil)
            }))
            confirm1.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            self?.present(confirm1, animated: true, completion: nil)
        }))

        menu.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(menu, animated: true, completion: nil)
    }
}
