import MapKit
import QuickLook
import UIKit
import InputBarAccessoryView
import AVFoundation
import DcCore
import SDWebImage

class ChatViewController: UITableViewController {
    var dcContext: DcContext
    let outgoingAvatarOverlap: CGFloat = 17.5
    let loadCount = 30
    let chatId: Int
    var messageIds: [Int] = []

    var msgChangedObserver: Any?
    var incomingMsgObserver: Any?
    var ephemeralTimerModifiedObserver: Any?

    var lastContentOffset: CGFloat = -1
    var isKeyboardShown: Bool = false
    lazy var isGroupChat: Bool = {
        return dcContext.getChat(chatId: chatId).isGroup
    }()

    /// The `InputBarAccessoryView` used as the `inputAccessoryView` in the view controller.
    open var messageInputBar = InputBarAccessoryView()

    open override var shouldAutorotate: Bool {
        return false
    }

    private weak var timer: Timer?

    lazy var navBarTap: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(chatProfilePressed))
    }()

    private var locationStreamingItem: UIBarButtonItem = {
        let indicator = LocationStreamingIndicator()
        return UIBarButtonItem(customView: indicator)
    }()

    private lazy var muteItem: UIBarButtonItem = {
        let imageView = UIImageView()
        imageView.tintColor = DcColors.defaultTextColor
        imageView.image =  #imageLiteral(resourceName: "volume_off").withRenderingMode(.alwaysTemplate)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        return UIBarButtonItem(customView: imageView)
    }()

    private lazy var ephemeralMessageItem: UIBarButtonItem = {
        let imageView = UIImageView()
        imageView.tintColor = DcColors.defaultTextColor
        imageView.image =  #imageLiteral(resourceName: "ephemeral_timer").withRenderingMode(.alwaysTemplate)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        return UIBarButtonItem(customView: imageView)
    }()

    private lazy var badgeItem: UIBarButtonItem = {
        let badge: InitialsBadge
        let chat = dcContext.getChat(chatId: chatId)
        if let image = chat.profileImage {
            badge = InitialsBadge(image: image, size: 28, accessibilityLabel: String.localized("menu_view_profile"))
        } else {
            badge = InitialsBadge(
                name: chat.name,
                color: chat.color,
                size: 28,
                accessibilityLabel: String.localized("menu_view_profile")
            )
            badge.setLabelFont(UIFont.systemFont(ofSize: 14))
        }
        badge.setVerified(chat.isProtected)
        badge.accessibilityTraits = .button
        return UIBarButtonItem(customView: badge)
    }()

    /// The `BasicAudioController` controll the AVAudioPlayer state (play, pause, stop) and update audio cell UI accordingly.
    private lazy var audioController = AudioController(dcContext: dcContext, chatId: chatId)

    private var disableWriting: Bool
    private var showNamesAboveMessage: Bool
    var showCustomNavBar = true
    var highlightedMsg: Int?

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    var emptyStateView: EmptyStateLabel = {
        let view =  EmptyStateLabel()
        return view
    }()

    init(dcContext: DcContext, chatId: Int, highlightedMsg: Int? = nil) {
        let dcChat = dcContext.getChat(chatId: chatId)
        self.dcContext = dcContext
        self.chatId = chatId
        self.disableWriting = !dcChat.canSend
        self.showNamesAboveMessage = dcChat.isGroup
        self.highlightedMsg = highlightedMsg
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.tableView = ChatTableView(messageInputBar: self.disableWriting ? nil : messageInputBar)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.view = self.tableView
    }

    override func viewDidLoad() {
        tableView.register(TextMessageCell.self, forCellReuseIdentifier: "text")
        tableView.register(ImageTextCell.self, forCellReuseIdentifier: "image")
        tableView.register(FileTextCell.self, forCellReuseIdentifier: "file")
        tableView.register(InfoMessageCell.self, forCellReuseIdentifier: "info")
        tableView.register(AudioMessageCell.self, forCellReuseIdentifier: "audio")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        super.viewDidLoad()
        if !dcContext.isConfigured() {
            // TODO: display message about nothing being configured
            return
        }
        configureEmptyStateView()

        if !disableWriting {
            configureMessageInputBar()
            messageInputBar.inputTextView.text = textDraft
        }


        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(setTextDraft),
                                       name: UIApplication.willResignActiveNotification,
                                       object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        prepareContextMenu()
    }

    @objc func keyboardDidShow(_ notification: Notification) {
        isKeyboardShown = true
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if keyboardSize.height > tableView.inputAccessoryView?.frame.height ?? 0 {
                if self.isLastRowVisible() {
                    DispatchQueue.main.async { [weak self] in
                        self?.scrollToBottom(animated: true)
                    }
                }
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        isKeyboardShown = false
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            //reload table
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.messageIds = self.getMessageIds()
                self.tableView.reloadData()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
    }

    private func configureEmptyStateView() {
        view.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40).isActive = true
        emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40).isActive = true
        emptyStateView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        emptyStateView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.becomeFirstResponder()
        // this will be removed in viewWillDisappear
        navigationController?.navigationBar.addGestureRecognizer(navBarTap)

        if showCustomNavBar {
            updateTitle(chat: dcContext.getChat(chatId: chatId))
        }

        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
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
        ) { [weak self] notification in
            guard let self = self else { return }
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

        ephemeralTimerModifiedObserver = nc.addObserver(
            forName: dcEphemeralTimerModified,
            object: nil, queue: OperationQueue.main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.updateTitle(chat: self.dcContext.getChat(chatId: self.chatId))
        }

        loadMessages()

        if RelayHelper.sharedInstance.isForwarding() {
            askToForwardMessage()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppStateRestorer.shared.storeLastActiveChat(chatId: chatId)

        // things that do not affect the chatview
        // and are delayed after the view is displayed
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.dcContext.marknoticedChat(chatId: self.chatId)
        }
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
        if let ephemeralTimerModifiedObserver = self.ephemeralTimerModifiedObserver {
            nc.removeObserver(ephemeralTimerModifiedObserver)
        }
        audioController.stopAnyOngoingPlaying()
        stopTimer()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let lastSectionVisibleBeforeTransition = self.isLastRowVisible()
        coordinator.animate(
            alongsideTransition: { [weak self] _ in
                guard let self = self else { return }
                if self.showCustomNavBar {
                    self.navigationItem.setRightBarButton(self.badgeItem, animated: true)
                }
                if lastSectionVisibleBeforeTransition {
                    self.scrollToBottom(animated: false)
                }
            },
            completion: {[weak self] _ in
                guard let self = self else { return }
                self.updateTitle(chat: self.dcContext.getChat(chatId: self.chatId))
                if lastSectionVisibleBeforeTransition {
                    DispatchQueue.main.async { [weak self] in
                        self?.tableView.reloadData()
                        self?.scrollToBottom(animated: false)
                    }
                }
            }
        )
        super.viewWillTransition(to: size, with: coordinator)
    }

    /// UITableView methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageIds.count //viewModel.numberOfRowsIn(section: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        _ = handleUIMenu()

        let id = messageIds[indexPath.row]
        let message = DcMsg(id: id)

        if message.isInfo {
            let cell = tableView.dequeueReusableCell(withIdentifier: "info", for: indexPath) as? InfoMessageCell ?? InfoMessageCell()
            cell.update(msg: message)
            return cell
        }

        let cell: BaseMessageCell
        if message.type == DC_MSG_IMAGE || message.type == DC_MSG_GIF || message.type == DC_MSG_VIDEO {
            cell = tableView.dequeueReusableCell(withIdentifier: "image", for: indexPath) as? ImageTextCell ?? ImageTextCell()
        } else if message.type == DC_MSG_FILE {
            if message.isSetupMessage {
                cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath) as? TextMessageCell ?? TextMessageCell()
                message.text = String.localized("autocrypt_asm_click_body")
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: "file", for: indexPath) as? FileTextCell ?? FileTextCell()
            }
        } else if message.type == DC_MSG_AUDIO ||  message.type == DC_MSG_VOICE {
            let audioMessageCell: AudioMessageCell = tableView.dequeueReusableCell(withIdentifier: "audio",
                                                                                      for: indexPath) as? AudioMessageCell ?? AudioMessageCell()
            audioController.update(audioMessageCell, with: message.id)
            cell = audioMessageCell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath) as? TextMessageCell ?? TextMessageCell()
        }

        cell.baseDelegate = self
        cell.update(msg: message,
                    messageStyle: configureMessageStyle(for: message, at: indexPath),
                    isAvatarVisible: configureAvatarVisibility(for: message, at: indexPath),
                    isGroup: isGroupChat)
        return cell
    }

    public override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastContentOffset = scrollView.contentOffset.y
    }

    public override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            markSeenMessagesInVisibleArea()
        }

        if scrollView.contentOffset.y < lastContentOffset {
            if isKeyboardShown {
                tableView.endEditing(true)
                tableView.becomeFirstResponder()
            }
        }
        lastContentOffset = -1
    }

    public override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        markSeenMessagesInVisibleArea()
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?  {
        let action = UIContextualAction(style: .normal, title: nil,
                                        handler: { (action, view, completionHandler) in
                                            // Update data source when user taps action
                                            completionHandler(true)
                                        })
        if #available(iOS 12.0, *) {
            action.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "ic_reply_black" : "ic_reply")
        } else {
            action.image = UIImage(named: "ic_reply_black")
        }
        action.backgroundColor = DcColors.chatBackgroundColor
        action.accessibilityHint = String.localized("reply_noun")
        let configuration = UISwipeActionsConfiguration(actions: [action])

        return configuration
    }

    func markSeenMessagesInVisibleArea() {
        if let indexPaths = tableView.indexPathsForVisibleRows {
            let visibleMessagesIds = indexPaths.map { UInt32(messageIds[$0.row]) }
            if !visibleMessagesIds.isEmpty {
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.dcContext.markSeenMessages(messageIds: visibleMessagesIds)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let messageId = messageIds[indexPath.row]
        let message = DcMsg(id: messageId)
        if message.isSetupMessage {
            didTapAsm(msg: message, orgText: "")
        } else if message.type == DC_MSG_FILE ||
            message.type == DC_MSG_AUDIO ||
            message.type == DC_MSG_VOICE {
            showMediaGalleryFor(message: message)
        }
        _ = handleUIMenu()
    }

    func configureAvatarVisibility(for message: DcMsg, at indexPath: IndexPath) -> Bool {
        return isGroupChat && !message.isFromCurrentSender && !isNextMessageSameSender(currentMessage: message, at: indexPath)
    }

    func configureMessageStyle(for message: DcMsg, at indexPath: IndexPath) -> UIRectCorner {

        var corners: UIRectCorner = []

        if message.isFromCurrentSender { //isFromCurrentSender(message: message) {
            corners.formUnion(.topLeft)
            corners.formUnion(.bottomLeft)
            if !isPreviousMessageSameSender(currentMessage: message, at: indexPath) {
                corners.formUnion(.topRight)
            }
            if !isNextMessageSameSender(currentMessage: message, at: indexPath) {
                corners.formUnion(.bottomRight)
            }
        } else {
            corners.formUnion(.topRight)
            corners.formUnion(.bottomRight)
            if !isPreviousMessageSameSender(currentMessage: message, at: indexPath) {
                corners.formUnion(.topLeft)
            }
            if !isNextMessageSameSender(currentMessage: message, at: indexPath) {
                corners.formUnion(.bottomLeft)
            }
        }

        return corners
    }

    private func getBackgroundColor(for currentMessage: DcMsg) -> UIColor {
        return currentMessage.isFromCurrentSender ? DcColors.messagePrimaryColor : DcColors.messageSecondaryColor
    }

    private func isPreviousMessageSameSender(currentMessage: DcMsg, at indexPath: IndexPath) -> Bool {
        let previousRow = indexPath.row - 1
        if previousRow < 0 {
            return false
        }

        let messageId = messageIds[previousRow]
        let previousMessage = DcMsg(id: messageId)

        return previousMessage.fromContact.id == currentMessage.fromContact.id
    }

    private func isNextMessageSameSender(currentMessage: DcMsg, at indexPath: IndexPath) -> Bool {
        let nextRow = indexPath.row + 1
        if nextRow >= messageIds.count {
            return false
        }

        let messageId = messageIds[nextRow]
        let nextMessage = DcMsg(id: messageId)

        return nextMessage.fromContact.id == currentMessage.fromContact.id
    }


    private func updateTitle(chat: DcChat) {
        let titleView =  ChatTitleView()

        var subtitle = "ErrSubtitle"
        let chatContactIds = chat.contactIds
        if chat.isGroup {
            subtitle = String.localized(stringID: "n_members", count: chatContactIds.count)
        } else if chatContactIds.count >= 1 {
            if chat.isDeviceTalk {
                subtitle = String.localized("device_talk_subtitle")
            } else if chat.isSelfTalk {
                subtitle = String.localized("chat_self_talk_subtitle")
            } else {
                subtitle = DcContact(id: chatContactIds[0]).email
            }
        }

        titleView.updateTitleView(title: chat.name, subtitle: subtitle)
        navigationItem.titleView = titleView

        var rightBarButtonItems = [badgeItem]
        if chat.isSendingLocations {
            rightBarButtonItems.append(locationStreamingItem)
        }
        if chat.isMuted {
            rightBarButtonItems.append(muteItem)
        }

        if dcContext.getChatEphemeralTimer(chatId: chat.id) > 0 {
            rightBarButtonItems.append(ephemeralMessageItem)
        }

        navigationItem.rightBarButtonItems = rightBarButtonItems
    }

    // TODO: is the delay of one second needed?
    @objc
    private func refreshMessages() {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messageIds = self.getMessageIds()
                self.tableView.reloadData()
                if self.isLastRowVisible() {
                    self.scrollToBottom(animated: true)
                }
                self.showEmptyStateView(self.messageIds.isEmpty)
            }
        }
    }

    private func loadMessages() {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let wasLastRowVisible = self.isLastRowVisible()
                let wasMessageIdsEmpty = self.messageIds.isEmpty
                // update message ids
                self.messageIds = self.getMessageIds()
                self.tableView.reloadData()
                if let msgId = self.highlightedMsg, let msgPosition = self.messageIds.firstIndex(of: msgId) {
                    self.tableView.scrollToRow(at: IndexPath(row: msgPosition, section: 0), at: .top, animated: false)
                    self.highlightedMsg = nil
                } else if wasMessageIdsEmpty ||
                    wasLastRowVisible {
                    self.scrollToBottom(animated: false)
                }
                self.showEmptyStateView(self.messageIds.isEmpty)
            }
        }
    }

    func isLastRowVisible() -> Bool {
        guard !messageIds.isEmpty else { return false }

        let lastIndexPath = IndexPath(item: messageIds.count - 1, section: 0)
        return tableView.indexPathsForVisibleRows?.contains(lastIndexPath) ?? false
    }

    func scrollToBottom(animated: Bool) {
        if !messageIds.isEmpty {
            self.tableView.scrollToRow(at: IndexPath(row: self.messageIds.count - 1, section: 0), at: .bottom, animated: animated)
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
    
    private func getMessageIds() -> [Int] {
        return dcContext.getMessageIds(chatId: chatId)
    }

    @objc private func setTextDraft() {
        if let text = self.messageInputBar.inputTextView.text {
            dcContext.setDraft(chatId: chatId, draftText: text)
        }
    }

    private func configureMessageInputBar() {
        messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.placeholder = String.localized("chat_input_placeholder")
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.textColor = DcColors.defaultTextColor
        messageInputBar.backgroundView.backgroundColor = DcColors.chatBackgroundColor

        //scrollsToBottomOnKeyboardBeginsEditing = true

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
            }.onTouchUpInside { [weak self] _ in
                self?.clipperButtonPressed()
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
        if chatId != DC_CHAT_ID_DEADDROP {
            showChatDetail(chatId: chatId)
        }
    }

    @objc private func clipperButtonPressed() {
        showClipperOptions()
    }

    private func showClipperOptions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .safeActionSheet)
        let galleryAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:))
        let cameraAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:))
        let documentAction = UIAlertAction(title: String.localized("files"), style: .default, handler: documentActionPressed(_:))
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
        self.present(alert, animated: true, completion: {
            // unfortunately, voiceMessageAction.accessibilityHint does not work,
            // but this hack does the trick
            if UIAccessibility.isVoiceOverRunning {
                if let view = voiceMessageAction.value(forKey: "__representer") as? UIView {
                    view.accessibilityHint = String.localized("a11y_voice_message_hint_ios")
                }
            }
        })
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
            self.showChat(chatId: chatId)
        } else {
            confirmationAlert(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), email),
                              actionTitle: String.localized("start_chat"),
                              actionHandler: { _ in
                                self.dismiss(animated: true, completion: nil)
                                let chatId = self.dcContext.createChatByContactId(contactId: contactId)
                                self.showChat(chatId: chatId)})
        }
    }

    private func askToDeleteMessage(id: Int) {
        let title = String.localized(stringID: "ask_delete_messages", count: 1)
        confirmationAlert(title: title, actionTitle: String.localized("delete"), actionStyle: .destructive,
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
                                self.navigationController?.popViewController(animated: true)})
        }
    }

    // MARK: - coordinator
    private func showChatDetail(chatId: Int) {
        let chat = dcContext.getChat(chatId: chatId)
        switch chat.chatType {
        case .SINGLE:
            if let contactId = chat.contactIds.first {
                let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: contactId)
                navigationController?.pushViewController(contactDetailController, animated: true)
            }
        case .GROUP, .VERIFIEDGROUP:
            let groupChatDetailViewController = GroupChatDetailViewController(chatId: chatId, dcContext: dcContext)
            navigationController?.pushViewController(groupChatDetailViewController, animated: true)
        }
    }

    func showChat(chatId: Int) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            navigationController?.popToRootViewController(animated: false)
            appDelegate.appCoordinator.showChat(chatId: chatId)
        }
    }

    private func showDocumentLibrary() {
        mediaPicker?.showDocumentLibrary()
    }

    private func showVoiceMessageRecorder() {
        mediaPicker?.showVoiceRecorder()
    }

    private func showCameraViewController() {
        mediaPicker?.showCamera()
    }

    private func showPhotoVideoLibrary(delegate: MediaPickerDelegate) {
        mediaPicker?.showPhotoVideoLibrary()
    }

    private func showMediaGallery(currentIndex: Int, msgIds: [Int]) {
        let betterPreviewController = PreviewController(type: .multi(msgIds, currentIndex))
        let nav = UINavigationController(rootViewController: betterPreviewController)
        nav.modalPresentationStyle = .fullScreen
        navigationController?.present(nav, animated: true)
    }

    private func documentActionPressed(_ action: UIAlertAction) {
        showDocumentLibrary()
    }

    private func voiceMessageButtonPressed(_ action: UIAlertAction) {
        showVoiceMessageRecorder()
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        showCameraViewController()
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        showPhotoVideoLibrary(delegate: self)
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

    func updateMessage(_ messageId: Int) {
        if messageIds.firstIndex(where: { $0 == messageId }) != nil {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.dcContext.markSeenMessages(messageIds: [UInt32(messageId)])
            }
            let wasLastSectionVisible = self.isLastRowVisible()
            tableView.reloadData()
            if wasLastSectionVisible {
                self.scrollToBottom(animated: true)
            }
        } else {
            let msg = DcMsg(id: messageId)
            if msg.chatId == chatId {
                insertMessage(msg)
            }
        }
    }

    func insertMessage(_ message: DcMsg) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.dcContext.markSeenMessages(messageIds: [UInt32(message.id)])
        }

        let wasLastSectionVisible = isLastRowVisible()
        messageIds.append(message.id)
        emptyStateView.isHidden = true

        tableView.reloadData()
        if wasLastSectionVisible || message.isFromCurrentSender {
            scrollToBottom(animated: true)
        }
    }

    private func sendTextMessage(message: String) {
        DispatchQueue.global().async {
            self.dcContext.sendTextInChat(id: self.chatId, message: message)
        }
    }

    private func sendImage(_ image: UIImage, message: String? = nil) {
        DispatchQueue.global().async {
            if let path = DcUtils.saveImage(image: image) {
                self.sendImageMessage(viewType: DC_MSG_IMAGE, image: image, filePath: path)
            }
        }
    }

    private func sendAnimatedImage(url: NSURL) {
        if let path = url.path {
            let result = SDAnimatedImage(contentsOfFile: path)
            if let result = result,
                let animatedImageData = result.animatedImageData,
                let pathInDocDir = DcUtils.saveImage(data: animatedImageData, suffix: "gif") {
                self.sendImageMessage(viewType: DC_MSG_GIF, image: result, filePath: pathInDocDir)
            }
        }
    }

    private func sendImageMessage(viewType: Int32, image: UIImage, filePath: String, message: String? = nil) {
        let msg = DcMsg(viewType: viewType)
        msg.setFile(filepath: filePath)
        msg.text = (message ?? "").isEmpty ? nil : message
        msg.sendInChat(id: self.chatId)
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
        if url.pathExtension == "gif" {
            sendAnimatedImage(url: url)
        } else if let data = try? Data(contentsOf: url as URL),
            let image = UIImage(data: data) {
            sendImage(image)
        }
    }

    // MARK: - Context menu
    private func prepareContextMenu() {
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: String.localized("info"), action: #selector(BaseMessageCell.messageInfo)),
            UIMenuItem(title: String.localized("delete"), action: #selector(BaseMessageCell.messageDelete)),
            UIMenuItem(title: String.localized("forward"), action: #selector(BaseMessageCell.messageForward))
        ]
        UIMenuController.shared.update()
    }

    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        return !DcMsg(id: messageIds[indexPath.row]).isInfo 
    }

    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return action == #selector(UIResponderStandardEditActions.copy(_:))
            || action == #selector(BaseMessageCell.messageInfo)
            || action == #selector(BaseMessageCell.messageDelete)
            || action == #selector(BaseMessageCell.messageForward)
    }

    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        // handle standard actions here, but custom actions never trigger this. it still needs to be present for the menu to display, though.
        switch action {
        case #selector(copy(_:)):
            let id = messageIds[indexPath.row]
            let msg = DcMsg(id: id)

            let pasteboard = UIPasteboard.general
            if msg.type == DC_MSG_TEXT {
                pasteboard.string = msg.text
            } else {
                pasteboard.string = msg.summary(chars: 10000000)
            }
        case #selector(BaseMessageCell.messageInfo(_:)):
            let msg = DcMsg(id: messageIds[indexPath.row])
            let msgViewController = MessageInfoViewController(dcContext: dcContext, message: msg)
            if let ctrl = navigationController {
                ctrl.pushViewController(msgViewController, animated: true)
            }
        case #selector(BaseMessageCell.messageDelete(_:)):
            let msg = DcMsg(id: messageIds[indexPath.row])
            askToDeleteMessage(id: msg.id)

        case #selector(BaseMessageCell.messageForward(_:)):
            let msg = DcMsg(id: messageIds[indexPath.row])
            RelayHelper.sharedInstance.setForwardMessage(messageId: msg.id)
            navigationController?.popViewController(animated: true)
        default:
            break
        }
    }

    func showMediaGalleryFor(indexPath: IndexPath) {
        let messageId = messageIds[indexPath.row]
        let message = DcMsg(id: messageId)
        showMediaGalleryFor(message: message)
    }

    func showMediaGalleryFor(message: DcMsg) {

        let msgIds = dcContext.getChatMedia(chatId: chatId, messageType: Int32(message.type), messageType2: 0, messageType3: 0)
        let index = msgIds.firstIndex(of: message.id) ?? 0
        showMediaGallery(currentIndex: index, msgIds: msgIds)
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

    func handleUIMenu() -> Bool {
        if UIMenuController.shared.isMenuVisible {
            UIMenuController.shared.setMenuVisible(false, animated: true)
            return true
        }
        return false
    }
}

// MARK: - BaseMessageCellDelegate
extension ChatViewController: BaseMessageCellDelegate {

    @objc func quoteTapped(indexPath: IndexPath) {
        _ = handleUIMenu()
        let msg = DcMsg(id: messageIds[indexPath.row])
        if let quoteMsg = msg.quoteMessage,
           let index = messageIds.firstIndex(of: quoteMsg.id) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }

    @objc func textTapped(indexPath: IndexPath) {
        if handleUIMenu() { return }
        let message = DcMsg(id: messageIds[indexPath.row])
        if message.isSetupMessage {
            didTapAsm(msg: message, orgText: "")
        }
    }

    @objc func phoneNumberTapped(number: String) {
        if handleUIMenu() { return }
        logger.debug("phone number tapped \(number)")
    }

    @objc func commandTapped(command: String) {
        if handleUIMenu() { return }
        logger.debug("command tapped \(command)")
    }

    @objc func urlTapped(url: URL) {
        if handleUIMenu() { return }
        if Utils.isEmail(url: url) {
            logger.debug("tapped on contact")
            let email = Utils.getEmailFrom(url)
            self.askToChatWith(email: email)
            ///TODO: implement handling
        } else {
            UIApplication.shared.open(url)
        }
    }

    @objc func imageTapped(indexPath: IndexPath) {
        if handleUIMenu() { return }
        showMediaGalleryFor(indexPath: indexPath)
    }

    @objc func avatarTapped(indexPath: IndexPath) {
        let message = DcMsg(id: messageIds[indexPath.row])
        let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: message.fromContactId)
        navigationController?.pushViewController(contactDetailController, animated: true)
    }
}

// MARK: - MediaPickerDelegate
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
