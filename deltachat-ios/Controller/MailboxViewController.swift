import UIKit
import DcCore

class MailboxViewController: ChatViewController {

    override init(dcContext: DcContext, chatId: Int) {
        super.init(dcContext: dcContext, chatId: chatId)
        hidesBottomBarWhenPushed = true
        showCustomNavBar = false
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = String.localized("menu_deaddrop")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        askToChat(messageId: messageIds[indexPath.row])
    }

    override func phoneNumberTapped(number: String) {}
    override func commandTapped(command: String) {}
    override func urlTapped(url: URL) {}
    override func imageTapped(indexPath: IndexPath) {
        askToChat(messageId: messageIds[indexPath.row])
    }
    override func avatarTapped(indexPath: IndexPath) {
        askToChat(messageId: messageIds[indexPath.row])
    }
    override func textTapped(indexPath: IndexPath) {
        askToChat(messageId: messageIds[indexPath.row])
    }


    func askToChat(messageId: Int) {
        if handleUIMenu() { return }
        let message = DcMsg(id: messageId)
        if message.isInfo {
            return
        }
        let dcContact = message.fromContact
        let title = String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
            let chat = self.dcContext.createChatByMessageId(messageId)
            self.showChat(chatId: chat.id)
        }))
        alert.addAction(UIAlertAction(title: String.localized("menu_block_contact"), style: .destructive, handler: { _ in
            dcContact.block()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }
}
