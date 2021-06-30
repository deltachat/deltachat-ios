import UIKit
import Social
import DcCore
import MobileCoreServices
import Intents
import SDWebImageWebPCoder
import SDWebImage


class ShareViewController: SLComposeServiceViewController {

    class SimpleLogger: Logger {
        func verbose(_ message: String) {
            print("ShareViewController", "verbose", message)
        }

        func debug(_ message: String) {
            print("ShareViewController", "debug", message)
        }

        func info(_ message: String) {
            print("ShareViewController", "info", message)
        }

        func warning(_ message: String) {
            print("ShareViewController", "warning", message)
        }

        func error(_ message: String) {
            print("ShareViewController", "error", message)
        }
    }

    let logger = SimpleLogger()
    let dcAccounts: DcAccounts = DcAccounts()
    lazy var dcContext: DcContext = {
        return dcAccounts.getSelected()
    }()

    var selectedChatId: Int?
    var selectedChat: DcChat?
    var shareAttachment: ShareAttachment?
    var isAccountConfigured: Bool = true
    var isLoading: Bool = false

    var previewImageHeightConstraint: NSLayoutConstraint?
    var previewImageWidthConstraint: NSLayoutConstraint?

    lazy var preview: SDAnimatedImageView? = {
        let imageView = SDAnimatedImageView(frame: .zero)
        imageView.clipsToBounds = true
        imageView.shouldGroupAccessibilityChildren = true
        imageView.isAccessibilityElement = false
        imageView.contentMode = .scaleAspectFit
        previewImageHeightConstraint = imageView.constraintHeightTo(96)
        previewImageWidthConstraint = imageView.constraintWidthTo(96)
        previewImageHeightConstraint?.isActive = true
        previewImageWidthConstraint?.isActive = true
        return imageView
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

    }

    override func presentationAnimationDidFinish() {
        dcAccounts.logger = logger
        dcAccounts.openDatabase()
        isAccountConfigured = dcContext.isConfigured()
        if isAccountConfigured {
            if #available(iOSApplicationExtension 13.0, *) {
               if let intent = self.extensionContext?.intent as? INSendMessageIntent, let chatId = Int(intent.conversationIdentifier ?? "") {
                   selectedChatId = chatId
               }
            }

            if selectedChatId == nil {
                selectedChatId = dcContext.getChatIdByContactId(contactId: Int(DC_CONTACT_ID_SELF))
            }
            if let chatId = selectedChatId {
                selectedChat = dcContext.getChat(chatId: chatId)
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.shareAttachment = ShareAttachment(dcContext: self.dcContext, inputItems: self.extensionContext?.inputItems, delegate: self)
            }
            reloadConfigurationItems()
            validateContent()
        } else {
            cancel()
        }
    }

    override func loadPreviewView() -> UIView! {
        return preview
    }

    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return  isAccountConfigured && !isLoading && (!(contentText?.isEmpty ?? true) || !(self.shareAttachment?.isEmpty ?? true))
    }

    private func setupNavigationBar() {
        guard let item = navigationController?.navigationBar.items?.first else { return }
        let button = UIBarButtonItem(
            title: String.localized("menu_send"),
            style: .done,
            target: self,
            action: #selector(appendPostTapped))
        item.rightBarButtonItem? = button
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
            logger.debug("configurationItems")
            // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.


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
            self.validateContent()
        }
    }

    func onThumbnailChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let preview = self.preview {
                preview.image = self.shareAttachment?.thumbnail ?? nil

                if let image = preview.image, image.sd_imageFormat == .webP {
                    self.previewImageWidthConstraint?.isActive = false
                    self.previewImageHeightConstraint?.isActive = false
                    preview.centerInSuperview()
                    self.textView.text = nil
                    self.textView.attributedText = nil
                    self.placeholder = nil
                    self.textView.isHidden = true
                }
            }
        }
    }

    func onLoadingStarted() {
        isLoading = true
    }

    func onLoadingFinished() {
        isLoading = false
        self.validateContent()
    }
}
