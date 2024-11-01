#if DEBUG
import DcCore
import UIKit

extension TestUtil {
    static let uitestMail = "uitest@delta.chat"

    /// Selects the account used for UI tests.
    ///
    /// If any of these asserts fail, reset the simulator with Device > Erase All Content and Settings
    static func selectUITestAccount() {
        // TODO: Maybe this logic should be in core because it is partly stolen from Android
        
        let dcAccounts = DcAccounts.shared

        // Try to select the test account
        if dcAccounts.getSelected().addr != uitestMail {
            for accountId in dcAccounts.getAll() {
                if dcAccounts.get(id: accountId).addr == uitestMail {
                    assert(dcAccounts.select(id: accountId))
                }
            }
        }

        // Create the test account if it doesn't exist
        if dcAccounts.getSelected().addr != uitestMail {
            // create new account
            let newAccountId = dcAccounts.add()
            let newAccount = dcAccounts.get(id: newAccountId)
            newAccount.setConfig("displayname", "Me")
            newAccount.setConfig("addr", uitestMail)
            newAccount.setConfig("configured_addr", uitestMail)
            newAccount.setConfig("configured_mail_pw", "abcd")
            newAccount.setConfigBool("configured", true)
            newAccount.setConfigBool("bcc_self", false)
            assert(dcAccounts.select(id: newAccountId))
        }

        // Clear the self-chat
        let account = dcAccounts.getSelected()
        let selfChat = account.createChatByContactId(contactId: Int(DC_CONTACT_ID_SELF))
        let oldMessages = account.getChatMsgs(chatId: selfChat, flags: 0)
        account.deleteMessages(msgIds: oldMessages)
        account.setDraft(chatId: Int(DC_CONTACT_ID_SELF), message: nil)

        // Delete the test account when the app terminates
        deleteTestAccount = AppTerminationListener {
            if dcAccounts.getAll().count > 1, dcAccounts.getSelected().addr == uitestMail {
                // user had multiple accounts, delete the test account
                assert(dcAccounts.remove(id: dcAccounts.getSelected().id))
            }
        }
    }

    static var deleteTestAccount: AppTerminationListener?
}

extension TestUtil {
    class AppTerminationListener {
        let willTerminate: () -> Void
        init(willTerminate: @escaping () -> Void) {
            self.willTerminate = willTerminate
            NotificationCenter.default.addObserver(self, selector: #selector(willTerminateFunc), name: UIApplication.willTerminateNotification, object: nil)
        }
        @objc func willTerminateFunc(_ handler: @escaping () -> Void) {
            willTerminate()
        }
    }
}
#endif
