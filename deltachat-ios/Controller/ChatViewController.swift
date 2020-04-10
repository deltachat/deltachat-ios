import MapKit
import QuickLook
import UIKit
import InputBarAccessoryView
import AVFoundation
import DcCore

protocol MediaSendHandler {
    func onSuccess()
}

extension ChatViewController: MediaSendHandler {
    func onSuccess() {
        refreshMessages()
    }
}

extension ChatViewController: MediaPickerDelegate {
    func onVideoSelected(url: NSURL) {
        sendVideo(url: url)
    }

    func onImageSelected(url: NSURL) {
        sendImage(url: url)
    }

    func onImageSelected(image: UIImage) {
        sendImage(image)
    }

    func onVoiceMessageRecorded(url: NSURL) {
        sendVoiceMessage(url: url)
    }

    func onDocumentSelected(url: NSURL) {
        sendDocumentMessage(url: url)
    }

}

class ChatViewController: MessagesViewController {

    var dcContext: DcContext
    weak var coordinator: ChatViewCoordinator?

    let outgoingAvatarOverlap: CGFloat = 17.5
    let loadCount = 30

    let chatId: Int
    let refreshControl = UIRefreshControl()
    var messageList: [DcMsg] = []

    var msgChangedObserver: Any?
    var incomingMsgObserver: Any?

    weak var timer: Timer?

    lazy var navBarTap: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(chatProfilePressed))
    }()

    /// The `BasicAudioController` controll the AVAudioPlayer state (play, pause, stop) and udpate audio cell UI accordingly.
    open lazy var audioController = BasicAudioController(messageCollectionView: messagesCollectionView)

    private var disableWriting: Bool
    private var showNamesAboveMessage: Bool
    var showCustomNavBar = true
    var previewView: UIView?

    var emptyStateView: PaddingLabel = {
        let view =  PaddingLabel()
        view.backgroundColor = DcColors.systemMessageBackgroundColor
        view.textColor = DcColors.defaultTextColor
        return view
    }()

    override var inputAccessoryView: UIView? {
        if disableWriting {
            return nil
        }
        return messageInputBar
    }

    init(dcContext: DcContext, chatId: Int) {
        let dcChat = dcContext.getChat(chatId: chatId)
        self.dcContext = dcContext
        self.chatId = chatId
        self.disableWriting = !dcChat.canSend
        self.showNamesAboveMessage = dcChat.isGroup
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        messagesCollectionView.register(InfoMessageCell.self)
        super.viewDidLoad()
        if !dcContext.isConfigured() {
            // TODO: display message about nothing being configured
            return
        }
        configureMessageCollectionView()
        configureEmptyStateView()

        if !disableWriting {
            configureMessageInputBar()
            messageInputBar.inputTextView.text = textDraft
            messageInputBar.inputTextView.becomeFirstResponder()
        }

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(setTextDraft),
                                       name: UIApplication.willResignActiveNotification,
                                       object: nil)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            //reload table
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.messageList = self.getMessageIds(self.messageList.count)
                self.messagesCollectionView.reloadDataAndKeepOffset()
                self.refreshControl.endRefreshing()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
    }

    private func configureEmptyStateView() {
        view.addSubview(emptyStateView)
        view.addConstraints([emptyStateView.constraintCenterYTo(view),
                             emptyStateView.constraintCenterXTo(view),
                             emptyStateView.constraintAlignLeadingTo(view, paddingLeading: 40),
                             emptyStateView.constraintAlignTrailingTo(view, paddingTrailing: 40)])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // this will be removed in viewWillDisappear
        navigationController?.navigationBar.addGestureRecognizer(navBarTap)

        if showCustomNavBar {
            updateTitle(chat: dcContext.getChat(chatId: chatId))
        }

        configureMessageMenu()

        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil,
            queue: OperationQueue.main
        ) { notification in
            if let ui = notification.userInfo {
                if self.disableWriting {
                    // always refresh, as we can't check currently
                    self.refreshMessages()
                } else if let id = ui["message_id"] as? Int {
                    if id > 0 {
                        self.updateMessage(id)
                    } else {
                        // change might be a deletion
                        self.refreshMessages()
                    }
                }
                if self.showCustomNavBar {
                    self.updateTitle(chat: self.dcContext.getChat(chatId: self.chatId))
                }
            }
        }

        incomingMsgObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil, queue: OperationQueue.main
        ) { notification in
            if let ui = notification.userInfo {
                if self.chatId == ui["chat_id"] as? Int {
                    if let id = ui["message_id"] as? Int {
                        if id > 0 {
                            self.insertMessage(DcMsg(id: id))
                        }
                    }
                }
            }
        }

        loadFirstMessages()

        if RelayHelper.sharedInstance.isForwarding() {
            askToForwardMessage()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppStateRestorer.shared.storeLastActiveChat(chatId: chatId)
        // things that do not affect the chatview
        // and are delayed after the view is displayed
        dcContext.marknoticedChat(chatId: chatId)
        let array = dcContext.getFreshMessages()
        UIApplication.shared.applicationIconBadgeNumber = array.count
        startTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // the navigationController will be used when chatDetail is pushed, so we have to remove that gestureRecognizer
        navigationController?.navigationBar.removeGestureRecognizer(navBarTap)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AppStateRestorer.shared.resetLastActiveChat()
        setTextDraft()
        let nc = NotificationCenter.default
        if let msgChangedObserver = self.msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let incomingMsgObserver = self.incomingMsgObserver {
            nc.removeObserver(incomingMsgObserver)
        }
        audioController.stopAnyOngoingPlaying()
        stopTimer()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let lastSectionVisibleBeforeTransition = self.isLastSectionVisible()
        coordinator.animate(
            alongsideTransition: { _ in
                if self.showCustomNavBar, let titleView = self.navigationItem.titleView as? ChatTitleView {
                    titleView.hideLocationStreamingIndicator()
                }
            },
            completion: { _ in
                self.updateTitle(chat: self.dcContext.getChat(chatId: self.chatId))
                self.messagesCollectionView.reloadDataAndKeepOffset()
                if lastSectionVisibleBeforeTransition {
                    self.messagesCollectionView.scrollToBottom(animated: false)
                }
            }
        )
        super.viewWillTransition(to: size, with: coordinator)
    }

    private func updateTitle(chat: DcChat) {
        let titleView =  ChatTitleView()

        var subtitle = "ErrSubtitle"
        let chatContactIds = chat.contactIds
        if chat.isGroup {
            subtitle = String.localizedStringWithFormat(NSLocalizedString("n_members", comment: ""), chatContactIds.count)
        } else if chatContactIds.count >= 1 {
            if chat.isDeviceTalk {
                subtitle = String.localized("device_talk_subtitle")
            } else if chat.isSelfTalk {
                subtitle = String.localized("chat_self_talk_subtitle")
            } else {
                subtitle = DcContact(id: chatContactIds[0]).email
            }
        }
        
        titleView.updateTitleView(title: chat.name, subtitle: subtitle, isLocationStreaming: chat.isSendingLocations)
        navigationItem.titleView = titleView

        let badge: InitialsBadge
        if let image = chat.profileImage {
            badge =  InitialsBadge(image: image, size: 28)
        } else {
            badge =  InitialsBadge(name: chat.name, color: chat.color, size: 28)
            badge.setLabelFont(UIFont.systemFont(ofSize: 14))
        }
        badge.setVerified(chat.isVerified)
        badge.accessibilityTraits = .button
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: badge)
    }

    @objc
    private func loadMoreMessages() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
            DispatchQueue.main.async {
                self.messageList = self.getMessageIds(self.loadCount, from: self.messageList.count) + self.messageList
                self.messagesCollectionView.reloadDataAndKeepOffset()
                self.refreshControl.endRefreshing()
            }
        }
    }

    @objc
    private func refreshMessages() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
            DispatchQueue.main.async {
                self.messageList = self.getMessageIds(self.messageList.count)
                self.messagesCollectionView.reloadDataAndKeepOffset()
                self.refreshControl.endRefreshing()
                if self.isLastSectionVisible() {
                    self.messagesCollectionView.scrollToBottom(animated: true)
                }
                self.showEmptyStateView(self.messageList.isEmpty)
            }
        }
    }

    private func loadFirstMessages() {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async {
                self.messageList = self.getMessageIds(self.loadCount)
                self.messagesCollectionView.reloadData()
                self.refreshControl.endRefreshing()
                self.messagesCollectionView.scrollToBottom(animated: false)
                self.showEmptyStateView(self.messageList.isEmpty)
            }
        }
    }

    private func showEmptyStateView(_ show: Bool) {
        if show {
            let dcChat = dcContext.getChat(chatId: chatId)
            if chatId == DC_CHAT_ID_DEADDROP {
                if dcContext.showEmails != DC_SHOW_EMAILS_ALL {
                    emptyStateView.text = String.localized("chat_no_contact_requests")
                } else {
                    emptyStateView.text = String.localized("chat_no_messages")
                }
            } else if dcChat.isGroup {
                if dcChat.isUnpromoted {
                    emptyStateView.text = String.localized("chat_new_group_hint")
                } else {
                    emptyStateView.text = String.localized("chat_no_messages")
                }
            } else if dcChat.isSelfTalk {
                emptyStateView.text = String.localized("saved_messages_explain")
            } else if dcChat.isDeviceTalk {
                emptyStateView.text = String.localized("device_talk_explain")
            } else {
                emptyStateView.text = String.localizedStringWithFormat(String.localized("chat_no_messages_hint"), dcChat.name, dcChat.name)
            }
            emptyStateView.isHidden = false
        } else {
            emptyStateView.isHidden = true
        }
    }

    private var textDraft: String? {
        return dcContext.getDraft(chatId: chatId)
    }

    private func getMessageIds(_ count: Int, from: Int? = nil) -> [DcMsg] {
        let cMessageIds = dcContext.getChatMessages(chatId: chatId)

        let ids: [Int]
        if let from = from {
            ids = Utils.copyAndFreeArrayWithOffset(inputArray: cMessageIds, len: count, skipEnd: from)
        } else {
            ids = Utils.copyAndFreeArrayWithLen(inputArray: cMessageIds, len: count)
        }

        let markIds: [UInt32] = ids.map { UInt32($0) }
        dcContext.markSeenMessages(messageIds: markIds, count: ids.count)

        return ids.map {
            DcMsg(id: $0)
        }
    }

    @objc private func setTextDraft() {
        if let text = self.messageInputBar.inputTextView.text {
            dcContext.setDraft(chatId: chatId, draftText: text)
        }
    }

    private func configureMessageMenu() {
        var menuItems: [UIMenuItem]

        menuItems = [
            UIMenuItem(title: String.localized("info"), action: #selector(MessageCollectionViewCell.messageInfo(_:))),
            UIMenuItem(title: String.localized("delete"), action: #selector(MessageCollectionViewCell.messageDelete(_:))),
            UIMenuItem(title: String.localized("forward"), action: #selector(MessageCollectionViewCell.messageForward(_:)))
        ]

        UIMenuController.shared.menuItems = menuItems
    }

    private func configureMessageCollectionView() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messageCellDelegate = self

        scrollsToBottomOnKeyboardBeginsEditing = true // default false
        maintainPositionOnKeyboardFrameChanged = true // default false
        messagesCollectionView.backgroundColor = DcColors.chatBackgroundColor
        messagesCollectionView.addSubview(refreshControl)
        refreshControl.addTarget(self, action: #selector(loadMoreMessages), for: .valueChanged)

        let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout
        layout?.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 2, right: 8)

        // Hide the outgoing avatar and adjust the label alignment to line up with the messages
        layout?.setMessageOutgoingAvatarSize(.zero)
        layout?.setMessageOutgoingMessageTopLabelAlignment(LabelAlignment(textAlignment: .right,
            textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)))
        layout?.setMessageOutgoingMessageBottomLabelAlignment(LabelAlignment(textAlignment: .right,
            textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)))

        // Set outgoing avatar to overlap with the message bubble
        layout?.setMessageIncomingMessageTopLabelAlignment(LabelAlignment(textAlignment: .left,
            textInsets: UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)))
        layout?.setMessageIncomingAvatarSize(CGSize(width: 30, height: 30))
        layout?.setMessageIncomingMessagePadding(UIEdgeInsets(
            top: 0, left: -18, bottom: 0, right: 0))
        layout?.setMessageIncomingMessageBottomLabelAlignment(LabelAlignment(textAlignment: .left,
            textInsets: UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)))

        layout?.setMessageIncomingAccessoryViewSize(CGSize(width: 30, height: 30))
        layout?.setMessageIncomingAccessoryViewPadding(HorizontalEdgeInsets(left: 8, right: 0))
        layout?.setMessageOutgoingAccessoryViewSize(CGSize(width: 30, height: 30))
        layout?.setMessageOutgoingAccessoryViewPadding(HorizontalEdgeInsets(left: 0, right: 8))

        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
    }

    private func configureMessageInputBar() {
        messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.placeholder = String.localized("chat_input_placeholder")
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.textColor = DcColors.defaultTextColor
        messageInputBar.backgroundView.backgroundColor = DcColors.chatBackgroundColor

        scrollsToBottomOnKeyboardBeginsEditing = true

        messageInputBar.inputTextView.backgroundColor = DcColors.inputFieldColor
        messageInputBar.inputTextView.placeholderTextColor = DcColors.placeholderColor
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 38)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 38)
        messageInputBar.inputTextView.layer.borderColor = UIColor.themeColor(light: UIColor(red: 200 / 255, green: 200 / 255, blue: 200 / 255, alpha: 1),
                                                                             dark: UIColor(red: 55 / 255, green: 55/255, blue: 55/255, alpha: 1)).cgColor
        messageInputBar.inputTextView.layer.borderWidth = 1.0
        messageInputBar.inputTextView.layer.cornerRadius = 13.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        configureInputBarItems()
    }

    private func configureInputBarItems() {

        messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 40, animated: false)


        let sendButtonImage = UIImage(named: "paper_plane")?.withRenderingMode(.alwaysTemplate)
        messageInputBar.sendButton.image = sendButtonImage
        messageInputBar.sendButton.accessibilityLabel = String.localized("menu_send")
        messageInputBar.sendButton.accessibilityTraits = .button
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.tintColor = UIColor(white: 1, alpha: 1)
        messageInputBar.sendButton.layer.cornerRadius = 20
        messageInputBar.middleContentViewPadding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        // this adds a padding between textinputfield and send button
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        messageInputBar.sendButton.setSize(CGSize(width: 40, height: 40), animated: false)
        messageInputBar.padding = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 12)

        let leftItems = [
            InputBarButtonItem()
                .configure {
                    $0.spacing = .fixed(0)
                    let clipperIcon = #imageLiteral(resourceName: "ic_attach_file_36pt").withRenderingMode(.alwaysTemplate)
                    $0.image = clipperIcon
                    $0.tintColor = DcColors.primary
                    $0.setSize(CGSize(width: 40, height: 40), animated: false)
                    $0.accessibilityLabel = String.localized("menu_add_attachment")
                    $0.accessibilityTraits = .button
                }.onSelected {
                    $0.tintColor = UIColor.themeColor(light: .lightGray, dark: .darkGray)
                }.onDeselected {
                    $0.tintColor = DcColors.primary
                }.onTouchUpInside { _ in
                    self.clipperButtonPressed()
                }
        ]

        messageInputBar.setStackViewItems(leftItems, forStack: .left, animated: false)

        // This just adds some more flare
        messageInputBar.sendButton
            .onEnabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.primary
                })
            }.onDisabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.colorDisabled
                })
            }
    }

    @objc private func chatProfilePressed() {
        coordinator?.showChatDetail(chatId: chatId)
    }

    // MARK: - UICollectionViewDataSource
    public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let messagesCollectionView = collectionView as? MessagesCollectionView else {
            fatalError("notMessagesCollectionView")
        }

        guard let messagesDataSource = messagesCollectionView.messagesDataSource else {
            fatalError("nilMessagesDataSource")
        }

        let message = messagesDataSource.messageForItem(at: indexPath, in: messagesCollectionView)
        switch message.kind {
        case .text, .attributedText, .emoji:
            let cell = messagesCollectionView.dequeueReusableCell(TextMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        case .info:
            let cell = messagesCollectionView.dequeueReusableCell(InfoMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        case .photo, .video:
            let cell = messagesCollectionView.dequeueReusableCell(MediaMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        case .photoText, .videoText, .fileText:
            let cell = messagesCollectionView.dequeueReusableCell(TextMediaMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        case .location:
            let cell = messagesCollectionView.dequeueReusableCell(LocationMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        case .contact:
            let cell = messagesCollectionView.dequeueReusableCell(ContactMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        case .custom:
            let cell = messagesCollectionView.dequeueReusableCell(InfoMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        case .audio:
            let cell = messagesCollectionView.dequeueReusableCell(AudioMessageCell.self, for: indexPath)
            cell.configure(with: message, at: indexPath, and: messagesCollectionView)
            return cell
        }
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        if action == NSSelectorFromString("messageInfo:") ||
            action == NSSelectorFromString("messageDelete:") ||
            action == NSSelectorFromString("messageForward:") {
            return true
        } else {
            return super.collectionView(collectionView, canPerformAction: action, forItemAt: indexPath, withSender: sender)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
        switch action {
        case NSSelectorFromString("messageInfo:"):
            let msg = messageList[indexPath.section]
            logger.info("message: View info \(msg.messageId)")

            let msgViewController = MessageInfoViewController(dcContext: dcContext, message: msg)
            if let ctrl = navigationController {
                ctrl.pushViewController(msgViewController, animated: true)
            }
        case NSSelectorFromString("messageDelete:"):
            let msg = messageList[indexPath.section]
            logger.info("message: delete \(msg.messageId)")
            askToDeleteMessage(id: msg.id)

        case NSSelectorFromString("messageForward:"):
            let msg = messageList[indexPath.section]
            RelayHelper.sharedInstance.setForwardMessage(messageId: msg.id)
            coordinator?.navigateBack()
        default:
            super.collectionView(collectionView, performAction: action, forItemAt: indexPath, withSender: sender)
        }
    }

    private func confirmationAlert(title: String, actionTitle: String, actionStyle: UIAlertAction.Style = .default, actionHandler: @escaping ((UIAlertAction) -> Void), cancelHandler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title,
                                             message: nil,
                                             preferredStyle: .safeActionSheet)
               alert.addAction(UIAlertAction(title: actionTitle, style: actionStyle, handler: actionHandler))

               alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: cancelHandler ?? { _ in
                   self.dismiss(animated: true, completion: nil)
               }))
               present(alert, animated: true, completion: nil)
    }

    private func askToChatWith(email: String) {
        let contactId = self.dcContext.createContact(name: "", email: email)
        if dcContext.getChatIdByContactId(contactId: contactId) != 0 {
            self.dismiss(animated: true, completion: nil)
            let chatId = self.dcContext.createChatByContactId(contactId: contactId)
            self.coordinator?.showChat(chatId: chatId)
        } else {
            confirmationAlert(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), email),
                              actionTitle: String.localized("start_chat"),
                              actionHandler: { _ in
                                self.dismiss(animated: true, completion: nil)
                                let chatId = self.dcContext.createChatByContactId(contactId: contactId)
                                self.coordinator?.showChat(chatId: chatId)})
        }
    }

    private func askToDeleteMessage(id: Int) {
        confirmationAlert(title: String.localized("delete"), actionTitle: String.localized("delete"), actionStyle: .destructive,
                          actionHandler: { _ in
                            self.dcContext.deleteMessage(msgId: id)
                            self.dismiss(animated: true, completion: nil)})
    }

    private func askToForwardMessage() {
        let chat = dcContext.getChat(chatId: self.chatId)
        if chat.isSelfTalk {
            RelayHelper.sharedInstance.forward(to: self.chatId)
        } else {
            confirmationAlert(title: String.localizedStringWithFormat(String.localized("ask_forward"), chat.name),
                          actionTitle: String.localized("menu_forward"),
                          actionHandler: { _ in
                            RelayHelper.sharedInstance.forward(to: self.chatId)
                            self.dismiss(animated: true, completion: nil)},
                          cancelHandler: { _ in
                            self.dismiss(animated: false, completion: nil)
                            self.coordinator?.navigateBack()})
        }
    }
}

// MARK: - MessagesDataSource
extension ChatViewController: MessagesDataSource {

    func numberOfSections(in _: MessagesCollectionView) -> Int {
        return messageList.count
    }

    func currentSender() -> SenderType {
        let currentSender = Sender(senderId: "1", displayName: "Alice")
        return currentSender
    }

    func messageForItem(at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageType {
        return messageList[indexPath.section]
    }

    func avatar(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> Avatar {
        let message = messageList[indexPath.section]
        let contact = message.fromContact
        return Avatar(image: contact.profileImage, initials: Utils.getInitials(inputName: contact.displayName))
    }

    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if isInfoMessage(at: indexPath) {
            return nil
        }

        if isTimeLabelVisible(at: indexPath) {
            return NSAttributedString(
                string: MessageKitDateFormatter.shared.string(from: message.sentDate),
                attributes: [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10),
                    NSAttributedString.Key.foregroundColor: DcColors.grayTextColor,
                ]
            )
        }

        return nil
    }

    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        var attributedString: NSMutableAttributedString?

        if showNamesAboveMessage && !isPreviousMessageSameSender(at: indexPath) {
            let name = message.sender.displayName
            let m = messageList[indexPath.section]
            attributedString = NSMutableAttributedString(string: name, attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: m.fromContact.color,
            ])
        }

        if isMessageForwarded(at: indexPath) {
            let forwardedString = NSMutableAttributedString(string: String.localized("forwarded_message"), attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: DcColors.grayTextColor,
            ])
            if attributedString == nil {
                attributedString = forwardedString
            } else {
                attributedString?.append(NSAttributedString(string: "\n", attributes: nil))
                attributedString?.append(forwardedString)
            }
        }

        return attributedString
    }

    func isMessageForwarded(at indexPath: IndexPath) -> Bool {
        let m = messageList[indexPath.section]
        return m.isForwarded
    }

    func isTimeLabelVisible(at indexPath: IndexPath) -> Bool {
        guard indexPath.section + 1 < messageList.count else { return false }

        let messageA = messageList[indexPath.section]
        let messageB = messageList[indexPath.section + 1]

        if messageA.fromContactId == messageB.fromContactId {
            return false
        }

        let calendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)
        let dateA = messageA.sentDate
        let dateB = messageB.sentDate

        let dayA = (calendar?.component(.day, from: dateA))
        let dayB = (calendar?.component(.day, from: dateB))

        return dayA != dayB
    }

    func isPreviousMessageSameSender(at indexPath: IndexPath) -> Bool {
        guard indexPath.section - 1 >= 0 else { return false }
        let messageA = messageList[indexPath.section - 1]
        let messageB = messageList[indexPath.section]

        if messageA.isInfo {
            return false
        }

        return messageA.fromContactId == messageB.fromContactId
    }

    func isInfoMessage(at indexPath: IndexPath) -> Bool {
        return messageList[indexPath.section].isInfo
    }

    func isImmediateNextMessageSameSender(at indexPath: IndexPath) -> Bool {
        guard indexPath.section + 1 < messageList.count else { return false }
        let messageA = messageList[indexPath.section]
        let messageB = messageList[indexPath.section + 1]

        if messageA.isInfo {
            return false
        }

        let dateA = messageA.sentDate
        let dateB = messageB.sentDate

        let timeinterval = dateB.timeIntervalSince(dateA)
        let minute = 60.0

        return messageA.fromContactId == messageB.fromContactId && timeinterval.isLessThanOrEqualTo(minute)

    }

    func isAvatarHidden(at indexPath: IndexPath) -> Bool {
        let message = messageList[indexPath.section]
        return isNextMessageSameSender(at: indexPath) || message.isInfo
    }

    func isNextMessageSameSender(at indexPath: IndexPath) -> Bool {
        guard indexPath.section + 1 < messageList.count else { return false }
        let messageA = messageList[indexPath.section]
        let messageB = messageList[indexPath.section + 1]

        if messageA.isInfo {
            return false
        }

        return messageA.fromContactId == messageB.fromContactId
    }

    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard indexPath.section < messageList.count else { return nil }
        let m = messageList[indexPath.section]

        if m.isInfo || isImmediateNextMessageSameSender(at: indexPath) {
            return nil
        }

        var timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: DcColors.grayDateColor,
            .paragraphStyle: NSParagraphStyle()
        ]

        let text = NSMutableAttributedString()
        if isFromCurrentSender(message: message) {
            if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
                style.alignment = .right
                timestampAttributes[.paragraphStyle] = style
            }

            text.append(NSAttributedString(string: m.formattedSentDate(), attributes: timestampAttributes))

            if m.showPadlock() {
                attachPadlock(to: text)
            }

            attachSendingState(m.state, to: text)
            return text
        }

        if !isAvatarHidden(at: indexPath) {
            if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
                style.firstLineHeadIndent = 22
                timestampAttributes[.paragraphStyle] = style
            }
        }

        text.append(NSAttributedString(string: m.formattedSentDate(), attributes: timestampAttributes))
        if m.showPadlock() {
            attachPadlock(to: text)
        }
        return text
    }

    private func attachPadlock(to text: NSMutableAttributedString) {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(named: "ic_lock")
        imageAttachment.image?.accessibilityIdentifier = String.localized("encrypted_message")
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([NSAttributedString.Key.baselineOffset: -1], range: NSRange(location: 0, length: 1))
        text.append(NSAttributedString(string: " "))
        text.append(imageString)
    }

    private func attachSendingState(_ state: Int, to text: NSMutableAttributedString) {
        let imageAttachment = NSTextAttachment()
        var offset = -4


        switch Int32(state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            imageAttachment.image = #imageLiteral(resourceName: "ic_hourglass_empty_36pt").scaleDownImage(toMax: 16)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_sending")
            offset = -2
        case DC_STATE_OUT_DELIVERED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_36pt").scaleDownImage(toMax: 18)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_delivered")
        case DC_STATE_OUT_MDN_RCVD:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_all_36pt").scaleDownImage(toMax: 18)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_read")
            text.append(NSAttributedString(string: " "))
        case DC_STATE_OUT_FAILED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_error_36pt").scaleDownImage(toMax: 16)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_error")
            offset = -2
        default:
            imageAttachment.image = nil
        }

        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([.baselineOffset: offset],
                                  range: NSRange(location: 0, length: 1))
        text.append(imageString)
    }

    func updateMessage(_ messageId: Int) {
        if let index = messageList.firstIndex(where: { $0.id == messageId }) {
            dcContext.markSeenMessages(messageIds: [UInt32(messageId)])

            messageList[index] = DcMsg(id: messageId)
            // Reload section to update header/footer labels
            messagesCollectionView.performBatchUpdates({
                messagesCollectionView.reloadSections([index])
                if index > 0 {
                    messagesCollectionView.reloadSections([index - 1])
                }
                if index < messageList.count - 1 {
                    messagesCollectionView.reloadSections([index + 1])
                }
            }, completion: { [weak self] _ in
                if self?.isLastSectionVisible() == true {
                    self?.messagesCollectionView.scrollToBottom(animated: true)
                }
            })
        } else {
            let msg = DcMsg(id: messageId)
            if msg.chatId == chatId {
                insertMessage(msg)
            }
        }
    }

    func insertMessage(_ message: DcMsg) {
        dcContext.markSeenMessages(messageIds: [UInt32(message.id)])
        messageList.append(message)
        emptyStateView.isHidden = true
        // Reload last section to update header/footer labels and insert a new one
        messagesCollectionView.performBatchUpdates({
            messagesCollectionView.insertSections([messageList.count - 1])
            if messageList.count >= 2 {
                messagesCollectionView.reloadSections([messageList.count - 2])
            }
        }, completion: { [weak self] _ in
            if self?.isLastSectionVisible() == true {
                self?.messagesCollectionView.scrollToBottom(animated: true)
            }
        })
    }

    private func sendTextMessage(message: String) {
        DispatchQueue.global().async {
            self.dcContext.sendTextInChat(id: self.chatId, message: message)
        }
    }

    private func sendImage(_ image: UIImage, message: String? = nil) {
        DispatchQueue.global().async {
            if let compressedImage = image.dcCompress() {
                // at this point image is compressed by 85% by default
                let pixelSize = compressedImage.imageSizeInPixel()
                let path = Utils.saveImage(image: compressedImage)
                let msg = DcMsg(viewType: DC_MSG_IMAGE)
                msg.setFile(filepath: path, mimeType: "image/jpeg")
                msg.setDimension(width: pixelSize.width, height: pixelSize.height)
                msg.text = (message ?? "").isEmpty ? nil : message
                msg.sendInChat(id: self.chatId)
            }
        }
    }

    private func sendDocumentMessage(url: NSURL) {
        DispatchQueue.global().async {
            let msg = DcMsg(viewType: DC_MSG_FILE)
            msg.setFile(filepath: url.relativePath, mimeType: nil)
            msg.sendInChat(id: self.chatId)
        }
    }

    private func sendVoiceMessage(url: NSURL) {
        DispatchQueue.global().async {
            let msg = DcMsg(viewType: DC_MSG_VOICE)
            msg.setFile(filepath: url.relativePath, mimeType: "audio/m4a")
            msg.sendInChat(id: self.chatId)
        }
    }

    private func sendVideo(url: NSURL) {
        DispatchQueue.global().async {
            let msg = DcMsg(viewType: DC_MSG_VIDEO)
            msg.setFile(filepath: url.relativePath, mimeType: "video/mp4")
            msg.sendInChat(id: self.chatId)
        }
    }

    private func sendImage(url: NSURL) {
        if let data = try? Data(contentsOf: url as URL) {
            if let image = UIImage(data: data) {
                sendImage(image)
            }
        }
    }

    func isLastSectionVisible() -> Bool {
        guard !messageList.isEmpty else { return false }

        let lastIndexPath = IndexPath(item: 0, section: messageList.count - 1)
        return messagesCollectionView.indexPathsForVisibleItems.contains(lastIndexPath)
    }
}

// MARK: - MessagesDisplayDelegate
extension ChatViewController: MessagesDisplayDelegate {
    // MARK: - Text Messages
    func textColor(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UIColor {
        return DcColors.defaultTextColor
    }

    // MARK: - All Messages
    func backgroundColor(for message: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? DcColors.messagePrimaryColor : DcColors.messageSecondaryColor
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageStyle {
        if isInfoMessage(at: indexPath) {
            //styling is hard-coded in info cell
            return .none
        }

        var corners: UIRectCorner = []

        if isFromCurrentSender(message: message) {
            corners.formUnion(.topLeft)
            corners.formUnion(.bottomLeft)
            if !isPreviousMessageSameSender(at: indexPath) {
                corners.formUnion(.topRight)
            }
            if !isNextMessageSameSender(at: indexPath) {
                corners.formUnion(.bottomRight)
            }
        } else {
            corners.formUnion(.topRight)
            corners.formUnion(.bottomRight)
            if !isPreviousMessageSameSender(at: indexPath) {
                corners.formUnion(.topLeft)
            }
            if !isNextMessageSameSender(at: indexPath) {
                corners.formUnion(.bottomLeft)
            }
        }

        return .custom { view in
            let radius: CGFloat = 16
            let path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
            let mask = CAShapeLayer()
            mask.path = path.cgPath
            view.layer.mask = mask
        }
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) {
        let message = messageList[indexPath.section]
        let contact = message.fromContact
        let avatar = Avatar(image: contact.profileImage, initials: Utils.getInitials(inputName: contact.displayName))
        avatarView.set(avatar: avatar)
        avatarView.isHidden = isAvatarHidden(at: indexPath)
        avatarView.backgroundColor = contact.color
    }

    func enabledDetectors(for _: MessageType, at _: IndexPath, in _: MessagesCollectionView) -> [DetectorType] {
        return [.url, .phoneNumber]
    }

    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key: Any] {
        return  [ NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor,
                  NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
                  NSAttributedString.Key.underlineColor: DcColors.defaultTextColor ]
    }

}

// MARK: - MessagesLayoutDelegate
extension ChatViewController: MessagesLayoutDelegate {

    func cellTopLabelHeight(for _: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        if isTimeLabelVisible(at: indexPath) {
            return 18
        }
        return 0
    }

    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        if isInfoMessage(at: indexPath) {
            return 0
        }

        if !isPreviousMessageSameSender(at: indexPath) {
            return 40
        } else if isMessageForwarded(at: indexPath) {
            return 20
        }

        return 0
    }

    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in _: MessagesCollectionView) -> CGFloat {
        if isInfoMessage(at: indexPath) {
            return 0
        }

        if !isImmediateNextMessageSameSender(at: indexPath) {
            return 16
        }

        return 0
    }

    func heightForLocation(message _: MessageType, at _: IndexPath, with _: CGFloat, in _: MessagesCollectionView) -> CGFloat {
        return 40
    }

    func footerViewSize(for _: MessageType, at _: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return CGSize(width: messagesCollectionView.bounds.width, height: 20)
    }

    @objc private func clipperButtonPressed() {
        showClipperOptions()
    }

    private func showClipperOptions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .safeActionSheet)
        let galleryAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:))
        let cameraAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:))
        let documentAction = UIAlertAction(title: String.localized("documents"), style: .default, handler: documentActionPressed(_:))
        let voiceMessageAction = UIAlertAction(title: String.localized("voice_message"), style: .default, handler: voiceMessageButtonPressed(_:))
        let isLocationStreaming = dcContext.isSendingLocationsToChat(chatId: chatId)
        let locationStreamingAction = UIAlertAction(title: isLocationStreaming ? String.localized("stop_sharing_location") : String.localized("location"),
                                                    style: isLocationStreaming ? .destructive : .default,
                                                    handler: locationStreamingButtonPressed(_:))

        alert.addAction(cameraAction)
        alert.addAction(galleryAction)
        alert.addAction(documentAction)
        alert.addAction(voiceMessageAction)
        if UserDefaults.standard.bool(forKey: "location_streaming") {
            alert.addAction(locationStreamingAction)
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func documentActionPressed(_ action: UIAlertAction) {
        coordinator?.showDocumentLibrary(delegate: self)
    }

    private func voiceMessageButtonPressed(_ action: UIAlertAction) {
        coordinator?.showVoiceMessageRecorder(delegate: self)
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        coordinator?.showCameraViewController(delegate: self)
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        coordinator?.showPhotoVideoLibrary(delegate: self)
    }

    private func locationStreamingButtonPressed(_ action: UIAlertAction) {
        let isLocationStreaming = dcContext.isSendingLocationsToChat(chatId: chatId)
        if isLocationStreaming {
            locationStreamingFor(seconds: 0)
        } else {
            let alert = UIAlertController(title: String.localized("title_share_location"), message: nil, preferredStyle: .safeActionSheet)
            addDurationSelectionAction(to: alert, key: "share_location_for_5_minutes", duration: Time.fiveMinutes)
            addDurationSelectionAction(to: alert, key: "share_location_for_30_minutes", duration: Time.thirtyMinutes)
            addDurationSelectionAction(to: alert, key: "share_location_for_one_hour", duration: Time.oneHour)
            addDurationSelectionAction(to: alert, key: "share_location_for_two_hours", duration: Time.twoHours)
            addDurationSelectionAction(to: alert, key: "share_location_for_six_hours", duration: Time.sixHours)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func addDurationSelectionAction(to alert: UIAlertController, key: String, duration: Int) {
        let action = UIAlertAction(title: String.localized(key), style: .default, handler: { _ in
            self.locationStreamingFor(seconds: duration)
        })
        alert.addAction(action)
    }

    private func locationStreamingFor(seconds: Int) {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                return
            }
            self.dcContext.sendLocationsToChat(chatId: self.chatId, seconds: seconds)
            appDelegate.locationManager.shareLocation(chatId: self.chatId, duration: seconds)
    }

}

// MARK: - MessageCellDelegate
extension ChatViewController: MessageCellDelegate {
    @objc func didTapMessage(in cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell) {
            let message = messageList[indexPath.section]
            if message.isSetupMessage {
                didTapAsm(msg: message, orgText: "")
            } else if let url = message.fileURL {
                // find all other messages with same message type
                let previousUrls: [URL] = message.previousMediaURLs()
                let nextUrls: [URL] = message.nextMediaURLs()

                // these are the files user will be able to swipe trough
                let mediaUrls: [URL] = previousUrls + [url] + nextUrls
                coordinator?.showMediaGallery(currentIndex: previousUrls.count, mediaUrls: mediaUrls)
            }
        }
    }

    private func didTapAsm(msg: DcMsg, orgText: String) {
        let inputDlg = UIAlertController(
            title: String.localized("autocrypt_continue_transfer_title"),
            message: String.localized("autocrypt_continue_transfer_please_enter_code"),
            preferredStyle: .alert)
        inputDlg.addTextField(configurationHandler: { (textField) in
            textField.placeholder = msg.setupCodeBegin + ".."
            textField.text = orgText
            textField.keyboardType = UIKeyboardType.numbersAndPunctuation // allows entering spaces; decimalPad would require a mask to keep things readable
        })
        inputDlg.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))

        let okAction = UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            let textField = inputDlg.textFields![0]
            let modText = textField.text ?? ""
            let success = self.dcContext.continueKeyTransfer(msgId: msg.id, setupCode: modText)

            let alert = UIAlertController(
                title: String.localized("autocrypt_continue_transfer_title"),
                message: String.localized(success ? "autocrypt_continue_transfer_succeeded" : "autocrypt_bad_setup_code"),
                preferredStyle: .alert)
            if success {
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            } else {
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                let retryAction = UIAlertAction(title: String.localized("autocrypt_continue_transfer_retry"), style: .default, handler: { _ in
                    self.didTapAsm(msg: msg, orgText: modText)
                })
                alert.addAction(retryAction)
                alert.preferredAction = retryAction
            }
            self.navigationController?.present(alert, animated: true, completion: nil)
        })

        inputDlg.addAction(okAction)
        inputDlg.preferredAction = okAction // without setting preferredAction, cancel become shown *bold* as the preferred action
        navigationController?.present(inputDlg, animated: true, completion: nil)
    }

    @objc func didTapAvatar(in cell: MessageCollectionViewCell) {
        if let indexPath = messagesCollectionView.indexPath(for: cell) {
            let message = messageList[indexPath.section]
            let chat = dcContext.getChat(chatId: chatId)
            coordinator?.showContactDetail(of: message.fromContact.id, in: chat.chatType, chatId: chatId)
        }
    }

    @objc(didTapCellTopLabelIn:) func didTapCellTopLabel(in _: MessageCollectionViewCell) {
        logger.info("Top label tapped")
    }

    @objc(didTapCellBottomLabelIn:) func didTapCellBottomLabel(in _: MessageCollectionViewCell) {
        print("Bottom label tapped")
    }

    func didTapPlayButton(in cell: AudioMessageCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell),
            let message = messagesCollectionView.messagesDataSource?.messageForItem(at: indexPath, in: messagesCollectionView) else {
                print("Failed to identify message when audio cell receive tap gesture")
                return
        }
        guard audioController.state != .stopped else {
            // There is no audio sound playing - prepare to start playing for given audio message
            audioController.playSound(for: message, in: cell)
            return
        }
        if audioController.playingMessage?.messageId == message.messageId {
            // tap occur in the current cell that is playing audio sound
            if audioController.state == .playing {
                audioController.pauseSound(for: message, in: cell)
            } else {
                audioController.resumeSound()
            }
        } else {
            // tap occur in a difference cell that the one is currently playing sound. First stop currently playing and start the sound for given message
            audioController.stopAnyOngoingPlaying()
            audioController.playSound(for: message, in: cell)
        }
    }


    func didStartAudio(in cell: AudioMessageCell) {
        print("audio started")
    }

    func didStopAudio(in cell: AudioMessageCell) {
        print("audio stopped")
    }

    func didPauseAudio(in cell: AudioMessageCell) {
        print("audio paused")
    }


    @objc func didTapBackground(in cell: MessageCollectionViewCell) {
        print("background of message tapped")
    }
}

// MARK: - MessageLabelDelegate
extension ChatViewController: MessageLabelDelegate {

    func didSelectPhoneNumber(_ phoneNumber: String) {
        logger.info("phone open", phoneNumber)
        if let escapedPhoneNumber = phoneNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            if let url = NSURL(string: "tel:\(escapedPhoneNumber)") {
                UIApplication.shared.open(url as URL)
            }
        }
    }

    func didSelectURL(_ url: URL) {
        if Utils.isEmail(url: url) {
            print("tapped on contact")
            let email = Utils.getEmailFrom(url)
            self.askToChatWith(email: email)
            ///TODO: implement handling
        } else {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - LocationMessageDisplayDelegate
/*
 extension ChatViewController: LocationMessageDisplayDelegate {
 func annotationViewForLocation(message: MessageType, at indexPath: IndexPath, in messageCollectionView: MessagesCollectionView) -> MKAnnotationView? {
 let annotationView = MKAnnotationView(annotation: nil, reuseIdentifier: nil)
 let pinImage = #imageLiteral(resourceName: "ic_block_36pt").withRenderingMode(.alwaysTemplate)
 annotationView.image = pinImage
 annotationView.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
 return annotationView
 }
 func animationBlockForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> ((UIImageView) -> Void)? {
 return { view in
 view.layer.transform = CATransform3DMakeScale(0, 0, 0)
 view.alpha = 0.0
 UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
 view.layer.transform = CATransform3DIdentity
 view.alpha = 1.0
 }, completion: nil)
 }
 }
 }
 */

// MARK: - MessageInputBarDelegate
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        if inputBar.inputTextView.images.isEmpty {
            self.sendTextMessage(message: text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            let trimmedText = text.replacingOccurrences(of: "\u{FFFC}", with: "", options: .literal, range: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // only 1 attachment allowed for now, thus it takes the first one
            self.sendImage(inputBar.inputTextView.images[0], message: trimmedText)
        }
        inputBar.inputTextView.text = String()
        inputBar.inputTextView.attributedText = nil
    }
}

/*
 extension ChatViewController: MessageInputBarDelegate {
 }
 */

// MARK: - MessageCollectionViewCell
extension MessageCollectionViewCell {

    @objc func messageForward(_ sender: Any?) {
        // Get the collectionView
       if let collectionView = self.superview as? UICollectionView {
           // Get indexPath
           if let indexPath = collectionView.indexPath(for: self) {
               // Trigger action
               collectionView.delegate?.collectionView?(collectionView,
                   performAction: #selector(MessageCollectionViewCell.messageForward(_:)),
                   forItemAt: indexPath, withSender: sender)
            }
        }
    }


    @objc func messageDelete(_ sender: Any?) {
        // Get the collectionView
        if let collectionView = self.superview as? UICollectionView {
            // Get indexPath
            if let indexPath = collectionView.indexPath(for: self) {
                // Trigger action
                collectionView.delegate?.collectionView?(collectionView,
                    performAction: #selector(MessageCollectionViewCell.messageDelete(_:)),
                    forItemAt: indexPath, withSender: sender)
            }
        }
    }

    @objc func messageInfo(_ sender: Any?) {
        // Get the collectionView
        if let collectionView = self.superview as? UICollectionView {
            // Get indexPath
            if let indexPath = collectionView.indexPath(for: self) {
                // Trigger action
                collectionView.delegate?.collectionView?(collectionView,
                    performAction: #selector(MessageCollectionViewCell.messageInfo(_:)),
                    forItemAt: indexPath, withSender: sender)
            }
        }
    }
}
