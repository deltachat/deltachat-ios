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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didTapMessage(in cell: MessageCollectionViewCell) {
        askToChat(cell: cell)
    }

    override func didTapCellTopLabel(in cell: MessageCollectionViewCell) {
        askToChat(cell: cell)
    }

    override func didTapAvatar(in cell: MessageCollectionViewCell) {
        askToChat(cell: cell)
    }

    override func didTapBackground(in cell: MessageCollectionViewCell) {
        askToChat(cell: cell)
    }


    private func askToChat(cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell) {

            let message = messageList[indexPath.section]
            let dcContact = message.fromContact
            let title = String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr)
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                let chat = self.dcContext.createChatByMessageId(message.id)
                self.coordinator?.showChat(chatId: chat.id)
            }))
            alert.addAction(UIAlertAction(title: String.localized("menu_block_contact"), style: .destructive, handler: { _ in
                dcContact.block()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        }
    }
}
