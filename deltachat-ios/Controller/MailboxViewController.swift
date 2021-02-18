import UIKit
import DcCore

class MailboxViewController: ChatViewController {

    override init(dcContext: DcContext, chatId: Int, highlightedMsg: Int? = nil) {
        super.init(dcContext: dcContext, chatId: chatId)
        hidesBottomBarWhenPushed = true
        tableView.allowsSelectionDuringEditing = false
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

    override func phoneNumberTapped(number: String, indexPath: IndexPath) {}
    override func commandTapped(command: String, indexPath: IndexPath) {}
    override func urlTapped(url: URL, indexPath: IndexPath) {}
    override func imageTapped(indexPath: IndexPath) {
        askToChat(messageId: messageIds[indexPath.row])
    }
    override func avatarTapped(indexPath: IndexPath) {
        askToChat(messageId: messageIds[indexPath.row])
    }
    override func textTapped(indexPath: IndexPath) {
        askToChat(messageId: messageIds[indexPath.row])
    }

    // function builds the correct question when tapping on a deaddrop message.
    // returns a tuple (question, startButton, blockButton)
    public static func deaddropQuestion(context: DcContext, msg: DcMsg) -> (String, String, String) {
        let chat = context.getChat(chatId: msg.realChatId)
        if chat.isMailinglist {
            let question = String.localizedStringWithFormat(String.localized("ask_show_mailing_list"), chat.name)
            return (question, String.localized("yes"), String.localized("block"))
        } else {
            let contact = msg.fromContact
            let question = String.localizedStringWithFormat(String.localized("ask_start_chat_with"), contact.nameNAddr)
            return (question, String.localized("start_chat"), String.localized("menu_block_contact"))
        }
    }

    func askToChat(messageId: Int) {
        if handleUIMenu() { return }
        let message = DcMsg(id: messageId)
        if message.isInfo {
            return
        }
        let (title, startButton, blockButton) = MailboxViewController.deaddropQuestion(context: dcContext, msg: message)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: startButton, style: .default, handler: { _ in
            let chat = self.dcContext.decideOnContactRequest(messageId, DC_DECISION_START_CHAT)
            self.showChat(chatId: chat.id)
        }))
        alert.addAction(UIAlertAction(title: blockButton, style: .destructive, handler: { _ in
            self.dcContext.decideOnContactRequest(messageId, DC_DECISION_BLOCK)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }
}
