import UIKit
import Social
import DcCore
import MobileCoreServices
import Intents
import SDWebImageWebPCoder
import SDWebImage

let logger = getDcLogger()

class ShareViewController: SLComposeServiceViewController {

    let dcAccounts: DcAccounts = getDcAccounts()
    lazy var dcContext: DcContext = {
        return dcAccounts.getSelected()
    }()

    var selectedChatId: Int?
    var selectedChat: DcChat?
    var shareAttachment: ShareAttachment?
    var isAccountConfigured: Bool = true

    var previewImageHeightConstraint: NSLayoutConstraint?
    var previewImageWidthConstraint: NSLayoutConstraint?

    lazy var preview: SDAnimatedImageView? = {

        UIGraphicsBeginImageContext(CGSize(width: 96, height: 96))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let imageView = SDAnimatedImageView(image: image)
        imageView.clipsToBounds = true
        imageView.shouldGroupAccessibilityChildren = true
        imageView.isAccessibilityElement = false
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageHeightConstraint = imageView.constraintHeightTo(96)
        previewImageWidthConstraint = imageView.constraintWidthTo(96)
        previewImageHeightConstraint?.isActive = true
        previewImageWidthConstraint?.isActive = true
        return imageView
    }()

    lazy var initialsBadge: InitialsBadge = {
        let view = InitialsBadge(name: "", color: UIColor.clear, size: 28)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        // workaround for iOS13 bug
        if #available(iOS 13.0, *) {
            _ = NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { (_) in
                if let layoutContainerView = self.view.subviews.last {
                    layoutContainerView.frame.size.height += 10
                }
            }
        }
        placeholder = String.localized("chat_input_placeholder")
        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)

        dcAccounts.openDatabase(writeable: false)
        let accountIds = dcAccounts.getAll()
        for accountId in accountIds {
            let dcContext = dcAccounts.get(id: accountId)
            if !dcContext.isOpen() {
                do {
                    let secret = try KeychainManager.getAccountSecret(accountID: dcContext.id)
                    if !dcContext.open(passphrase: secret) {
                        logger.error("Failed to open database.")
                    }
                } catch KeychainError.unhandledError(let message, let status), KeychainError.accessError(let message, let status) {
                    logger.error("KeychainError. \(message). Error status: \(status)")
                } catch {
                    logger.error("\(error)")
                }
            }
        }

        if #available(iOSApplicationExtension 13.0, *) {
            if let intent = self.extensionContext?.intent as? INSendMessageIntent,
               let identifiers = intent.conversationIdentifier?.split(separator: "."),
               let contextId = Int(identifiers[0]),
               let chatId = Int(identifiers[1]) {
                if accountIds.contains(contextId) {
                    dcContext = dcAccounts.get(id: contextId)
                    selectedChatId = chatId
                } else {
                    logger.error("invalid INSendMessageIntent \(contextId) doesn't exist")
                    cancel()
                    return
                }
            }
        }

        isAccountConfigured = dcContext.isOpen() && dcContext.isConfigured()
        if !isAccountConfigured {
            logger.error("selected context \(dcContext.id) is not configured")
            cancel()
            return
        }

        if selectedChatId == nil {
            selectedChatId = dcContext.getChatIdByContactId(contactId: Int(DC_CONTACT_ID_SELF))
            logger.debug("selected chatID: \(String(describing: selectedChatId))")
        }

        let contact = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF))
        let title = dcContext.displayname ?? dcContext.addr ?? ""
        initialsBadge.setName(title)
        initialsBadge.setColor(contact.color)
        if let image = contact.profileImage {
            initialsBadge.setImage(image)
        }

        guard let chatId = selectedChatId else {
            cancel()
            return
        }
        selectedChat = dcContext.getChat(chatId: chatId)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.shareAttachment = ShareAttachment(dcContext: self.dcContext, inputItems: self.extensionContext?.inputItems, delegate: self)
            DispatchQueue.main.async {
                self.validateContent()
            }
        }
    }

    override func loadPreviewView() -> UIView! {
        return preview
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return  isAccountConfigured && (!(contentText?.isEmpty ?? true) || !(self.shareAttachment?.isEmpty ?? true))
    }

    private func setupNavigationBar() {
        guard let item = navigationController?.navigationBar.items?.first else { return }
        let button = UIBarButtonItem(
            title: String.localized("menu_send"),
            style: .done,
            target: self,
            action: #selector(appendPostTapped))
        item.rightBarButtonItem? = button

        let cancelButton = UIBarButtonItem(
            title: String.localized("cancel"),
            style: .done,
            target: self,
            action: #selector(onCancelPressed))

        let avatarItem = UIBarButtonItem(customView: initialsBadge)
        item.leftBarButtonItems = [avatarItem, cancelButton]
    }

    /// Invoked when the user wants to post.
    @objc
    private func appendPostTapped() {
        if let chatId = self.selectedChatId {
            guard var messages = shareAttachment?.messages else { return }
            if !self.contentText.isEmpty {
                if messages.count == 1 {
                    messages[0].text?.append(self.contentText)
                } else {
                    let message = dcContext.newMessage(viewType: DC_MSG_TEXT)
                    message.text = self.contentText
                    messages.insert(message, at: 0)
                }
            }
            let chatListController = SendingController(chatId: chatId, dcMsgs: messages, dcContext: dcContext)
            chatListController.delegate = self
            self.pushConfigurationViewController(chatListController)
        }
    }

    func quit() {
        dcAccounts.closeDatabase()

        // Inform the host that we're done, so it un-blocks its UI.
        self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        let item = SLComposeSheetConfigurationItem()
        if isAccountConfigured {
            // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
            // TODO: discuss if we want to add an item for the account selection.

            item?.title = String.localized("forward_to")
            item?.value = selectedChat?.name
            logger.debug("configurationItems chat name: \(String(describing: selectedChat?.name))")
            item?.tapHandler = {
                let chatListController = ChatListController(dcContext: self.dcContext, chatListDelegate: self)
                self.pushConfigurationViewController(chatListController)
            }
        } else {
            item?.title = String.localized("share_account_not_configured")
        }

        return [item as Any]
    }

    override func didSelectCancel() {
        quit()
    }

    @objc func onCancelPressed() {
        cancel()
    }
}

extension ShareViewController: ChatListDelegate {
    func onChatSelected(chatId: Int) {
        selectedChatId = chatId
        selectedChat = dcContext.getChat(chatId: chatId)
        reloadConfigurationItems()
        popConfigurationViewController()
    }
}

extension ShareViewController: SendingControllerDelegate {
    func onSendingAttemptFinished() {
        DispatchQueue.main.async {
            self.popConfigurationViewController()
            UserDefaults.shared?.set(true, forKey: UserDefaults.hasExtensionAttemptedToSend)
            self.quit()
        }
    }
}

extension ShareViewController: ShareAttachmentDelegate {
    func onUrlShared(url: URL) {
        DispatchQueue.main.async {
            if var contentText = self.contentText, !contentText.isEmpty {
                contentText.append("\n\(url.absoluteString)")
                self.textView.text = contentText
            } else {
                self.textView.text = "\(url.absoluteString)"
            }
            self.validateContent()
        }
    }

    func onAttachmentChanged() {
        DispatchQueue.main.async {
            if let shareAttachment = self.shareAttachment,
               let error = shareAttachment.error {
                logger.error(error)
                let alert = UIAlertController(title: nil, message: error, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                    self.quit()
                }))
                self.present(alert, animated: true, completion: nil)
            }
            self.validateContent()
        }
    }

    func onThumbnailChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let preview = self.preview {
                preview.image = self.shareAttachment?.thumbnail ?? nil
            }
        }
    }
}
