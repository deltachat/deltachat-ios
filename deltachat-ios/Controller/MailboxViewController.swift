import UIKit
import MessageKit

class MailboxViewController: ChatViewController {

    override init(dcContext: DcContext, chatId: Int) {
        super.init(dcContext: dcContext, chatId: chatId)
        hidesBottomBarWhenPushed = false
        disableWriting = true
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
        NavBarUtils.setBigTitle(navigationController: navigationController)
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
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr), message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                let chat = message.createChat()
                self.coordinator?.showChat(chatId: chat.id)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        }
    }
}
