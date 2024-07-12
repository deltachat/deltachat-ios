import MapKit
import MCEmojiPicker
import QuickLook
import UIKit
import AVFoundation
import DcCore
import SDWebImage

class ChatViewController: UITableViewController, UITableViewDropDelegate {
    public let chatId: Int

    private var dcContext: DcContext
    private var messageIds: [Int] = []
    private var msgChangedObserver: NSObjectProtocol?
    private var msgReadDeliveredReactionFailedObserver: NSObjectProtocol?
    private var incomingMsgObserver: NSObjectProtocol?
    private var chatModifiedObserver: NSObjectProtocol?
    private var ephemeralTimerModifiedObserver: NSObjectProtocol?
    private var isInitial = true
    private var isVisibleToUser: Bool = false
    private var keepKeyboard: Bool = false
    private var wasInputBarFirstResponder = false
    private var reactionMessageId: Int?
    private var contextMenuVisible = false

    private lazy var isGroupChat: Bool = {
        return dcContext.getChat(chatId: chatId).isGroup
    }()

    private lazy var draft: DraftModel = {
        return DraftModel(dcContext: dcContext, chatId: chatId)
    }()

    private lazy var dropInteraction: ChatDropInteraction = {
        let dropInteraction = ChatDropInteraction()
        dropInteraction.delegate = self
        return dropInteraction
    }()

    // search related
    private var activateSearch: Bool = false
    private var searchMessageIds: [Int] = []
    private var searchResultIndex: Int = 0
    private var debounceTimer: Timer?

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.inputAccessoryView = messageInputBar
        searchController.searchBar.autocorrectionType = .yes
        searchController.searchBar.keyboardType = .default
        return searchController
    }()

    private lazy var searchAccessoryBar: ChatSearchAccessoryBar = {
        let view = ChatSearchAccessoryBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEnabled = false
        return view
    }()

    private lazy var backgroundContainer: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        if let backgroundImageName = UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName) {
            view.sd_setImage(with: Utils.getBackgroundImageURL(name: backgroundImageName),
                             placeholderImage: nil,
                             options: [.retryFailed]) { [weak self] (_, error, _, _) in
                if let error = error {
                    logger.error("Error loading background image: \(error.localizedDescription)" )
                    DispatchQueue.main.async { [weak self] in
                        self?.setDefaultBackgroundImage(view: view)
                    }
                }
            }
        } else {
            setDefaultBackgroundImage(view: view)
        }
        return view
    }()

    /// The `InputBarAccessoryView` used as the `inputAccessoryView` in the view controller.
    let messageInputBar = InputBarAccessoryView()

    private lazy var draftArea: DraftArea = {
        let view = DraftArea()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        view.inputBarAccessoryView = messageInputBar
        return view
    }()

    private lazy var editingBar: ChatEditingBar = {
        let height = 52 + view.safeAreaInsets.bottom
        let view = ChatEditingBar(frame: .init(0, 0, 0, height))
        view.delegate = self
        return view
    }()

    open override var shouldAutorotate: Bool {
        return false
    }

    private weak var timer: Timer?

    private lazy var navBarTap: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(chatProfilePressed))
    }()

    private var locationStreamingItem: UIBarButtonItem = {
        return UIBarButtonItem(customView: LocationStreamingIndicator())
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

    private lazy var initialsBadge: InitialsBadge = {
        let badge: InitialsBadge
        badge = InitialsBadge(size: 37, accessibilityLabel: String.localized("menu_view_profile"))
        badge.setLabelFont(UIFont.systemFont(ofSize: 14))
        badge.accessibilityTraits = .button
        return badge
    }()

    private lazy var badgeItem: UIBarButtonItem = {
        return UIBarButtonItem(customView: initialsBadge)
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(onCancelPressed))
    }()

    private let titleView = ChatTitleView()

    private lazy var dcChat: DcChat = {
        return dcContext.getChat(chatId: chatId)
    }()

    private var customInputAccessoryView: UIView?
    override var inputAccessoryView: UIView? {
        get { customInputAccessoryView }
        set { customInputAccessoryView = newValue }
    }
    private var shouldBecomeFirstResponder: Bool = false
    override var canBecomeFirstResponder: Bool {
        return shouldBecomeFirstResponder
    }

    private func getMyReactions(messageId: Int) -> [String] {
        return dcContext.getMessageReactions(messageId: messageId)?.reactions.filter { $0.isFromSelf } .map { $0.emoji } ?? []
    }

    /// The `BasicAudioController` controll the AVAudioPlayer state (play, pause, stop) and update audio cell UI accordingly.
    private lazy var audioController = AudioController(dcContext: dcContext, chatId: chatId, delegate: self)

    private var keyboardManager: KeyboardManager? = KeyboardManager()

    private var highlightedMsg: Int?

    private lazy var mediaPicker: MediaPicker? = {
        let mediaPicker = MediaPicker(dcContext: dcContext, navigationController: navigationController)
        mediaPicker.delegate = self
        return mediaPicker
    }()

    private var emptyStateView: EmptyStateLabel = {
        let view =  EmptyStateLabel()
        view.isHidden = true
        return view
    }()

    init(dcContext: DcContext, chatId: Int, highlightedMsg: Int? = nil) {
        self.dcContext = dcContext
        self.chatId = chatId
        self.highlightedMsg = highlightedMsg
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.backgroundView = backgroundContainer
        tableView.register(TextMessageCell.self, forCellReuseIdentifier: TextMessageCell.reuseIdentifier)
        tableView.register(ImageTextCell.self, forCellReuseIdentifier: ImageTextCell.reuseIdentifier)
        tableView.register(FileTextCell.self, forCellReuseIdentifier: FileTextCell.reuseIdentifier)
        tableView.register(InfoMessageCell.self, forCellReuseIdentifier: InfoMessageCell.reuseIdentifier)
        tableView.register(AudioMessageCell.self, forCellReuseIdentifier: AudioMessageCell.reuseIdentifier)
        tableView.register(VideoInviteCell.self, forCellReuseIdentifier: VideoInviteCell.reuseIdentifier)
        tableView.register(WebxdcCell.self, forCellReuseIdentifier: WebxdcCell.reuseIdentifier)
        tableView.register(ContactCardCell.self, forCellReuseIdentifier: ContactCardCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.allowsMultipleSelectionDuringEditing = true

        navigationController?.setNavigationBarHidden(false, animated: false)

        if #available(iOS 13.0, *) {
            navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        }

        navigationItem.backButtonTitle = String.localized("chat")
        definesPresentationContext = true

        // Binding to the tableView will enable interactive dismissal
        keyboardManager?.bind(to: tableView)
        keyboardManager?.on(event: .didChangeFrame) { [weak self] _ in
            guard let self else { return }
            if self.isInitial {
                self.isInitial = false
                return
            }
            if self.isLastRowVisible() && !self.tableView.isDragging && !self.tableView.isDecelerating && self.highlightedMsg == nil {
                self.scrollToBottom()
            }
        }.on(event: .willChangeFrame) { [weak self] _ in
            guard let self else { return }
            if self.isLastRowVisible() && !self.tableView.isDragging && !self.tableView.isDecelerating && self.highlightedMsg == nil  && !self.isInitial {
                self.scrollToBottom()
            }
        }

        if !dcContext.isConfigured() {
            // TODO: display message about nothing being configured
            return
        }
        configureEmptyStateView()

        if dcChat.canSend {
            configureUIForWriting()
        } else if dcChat.isHalfBlocked {
            configureContactRequestBar()
        } else {
            messageInputBar.isHidden = true
        }
        loadMessages()
    }

    private func configureUIForWriting() {
        shouldBecomeFirstResponder = true
        configureMessageInputBar()
        draft.parse(draftMsg: dcContext.getDraft(chatId: chatId))
        messageInputBar.inputTextView.text = draft.text
        configureDraftArea(draft: draft, animated: false)
        tableView.dragInteractionEnabled = true
        tableView.dropDelegate = self
    }

    private func getTopInsetHeight() -> CGFloat {
        let navigationBarHeight = navigationController?.navigationBar.bounds.height ?? 0
        if let root = UIApplication.shared.keyWindow?.rootViewController {
            return navigationBarHeight + root.view.safeAreaInsets.top
        }
        return UIApplication.shared.statusBarFrame.height + navigationBarHeight
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            // reload table
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      let appDelegate = UIApplication.shared.delegate as? AppDelegate
                else { return }
                
                if appDelegate.appIsInForeground() {
                    self.messageIds = self.dcContext.getChatMsgs(chatId: self.chatId)
                    self.reloadData()
                } else {
                    logger.warning("startTimer() must not be executed in background")
                }
            }
        }
    }

    public func activateSearchOnAppear() {
        activateSearch = true
        navigationItem.searchController = self.searchController
    }

    private func stopTimer() {
        if let timer = timer {
            timer.invalidate()
        }
        timer = nil
    }

    private func configureEmptyStateView() {
        emptyStateView.addCenteredTo(parentView: view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // this will be removed in viewWillDisappear
        navigationController?.navigationBar.addGestureRecognizer(navBarTap)
        updateTitle()

        if activateSearch {
            activateSearch = false
            DispatchQueue.main.async { [weak self] in
                self?.searchController.isActive = true
            }
        }

        if RelayHelper.shared.isForwarding() {
            if RelayHelper.shared.forwardIds != nil {
                askToForwardMessage()
            } else if RelayHelper.shared.forwardFileData != nil || RelayHelper.shared.forwardText != nil {
                if let text = RelayHelper.shared.forwardText {
                    messageInputBar.inputTextView.text = text
                }
                if let data = RelayHelper.shared.forwardFileData {
                    guard let file = FileHelper.saveData(data: data, name: RelayHelper.shared.forwardFileName, directory: .cachesDirectory) else { return }
                    stageDocument(url: NSURL(fileURLWithPath: file))
                }
                RelayHelper.shared.finishRelaying()
            }
        } else if RelayHelper.shared.isMailtoHandling() {
            messageInputBar.inputTextView.text = RelayHelper.shared.mailtoDraft
            RelayHelper.shared.finishRelaying()
        }

        if dcChat.canSend {
            shouldBecomeFirstResponder = true

            if wasInputBarFirstResponder {
                messageInputBar.inputTextView.becomeFirstResponder()
            } else {
                becomeFirstResponder()
            }
        }


        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let msgId = self.highlightedMsg, self.messageIds.firstIndex(of: msgId) != nil {
                self.scrollToMessage(msgId: msgId, animated: false)
            } else if self.isInitial {
                self.scrollToLastUnseenMessage()
            }
        }

        messageInputBar.scrollDownButton.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppStateRestorer.shared.storeLastActiveChat(chatId: chatId)

        // things that do not affect the chatview
        // and are delayed after the view is displayed
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            self.dcContext.marknoticedChat(chatId: self.chatId)
        }

        handleUserVisibility(isVisible: true)
        messageInputBar.backgroundView.backgroundColor = DcColors.defaultTransparentBackgroundColor
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // the navigationController will be used when chatDetail is pushed, so we have to remove that gestureRecognizer
        navigationController?.navigationBar.removeGestureRecognizer(navBarTap)
        wasInputBarFirstResponder = messageInputBar.inputTextView.isFirstResponder
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AppStateRestorer.shared.resetLastActiveChat()
        handleUserVisibility(isVisible: false)
        audioController.stopAnyOngoingPlaying()
        messageInputBar.inputTextView.resignFirstResponder()
        if !wasInputBarFirstResponder {
            resignFirstResponder()
        }

        wasInputBarFirstResponder = false
        shouldBecomeFirstResponder = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            removeObservers()
            draft.save(context: dcContext)
            keyboardManager = nil
        } else {
            setupObservers()
        }
    }

    // MARK: - Notifications

    @objc private func handleMessagesChanged(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }

        let chatId = ui["chat_id"] as? Int ?? 0
        if chatId == 0 || chatId == self.chatId {
            let messageId = ui["message_id"] as? Int ?? 0
            if messageId > 0 {
                let msg = self.dcContext.getMessage(id: messageId)
                if msg.state == DC_STATE_OUT_DRAFT && msg.type == DC_MSG_WEBXDC {
                    draft.draftMsg = msg
                    configureDraftArea(draft: draft, animated: false)
                    return
                }
            }

            if isLastRowScrolledToBottom() {
                scrollToBottom(animated: true)
            }

            refreshMessages()
            updateTitle()
            markSeenMessagesInVisibleArea()

        }
    }

    @objc private func handleMsgReadDeliveredReactionFailed(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }

        let chatId = ui["chat_id"] as? Int ?? 0
        if chatId == 0 || chatId == self.chatId {
            let messageId = ui["message_id"] as? Int ?? 0
            if messageId > 0 {
                let msg = self.dcContext.getMessage(id: messageId)
                if msg.state == DC_STATE_OUT_DRAFT && msg.type == DC_MSG_WEBXDC {
                    draft.draftMsg = msg
                    configureDraftArea(draft: draft, animated: false)
                    return
                }
            }

            refreshMessages()
            updateTitle()
            markSeenMessagesInVisibleArea()
        }
    }

    private func setupObservers() {
        let nc = NotificationCenter.default
        if msgChangedObserver == nil {
            msgChangedObserver = nc.addObserver(
                forName: .messagesChanged,
                object: nil,
                queue: OperationQueue.main
            ) { [weak self] notification in
                self?.handleMessagesChanged(notification)
            }
        }

        if msgReadDeliveredReactionFailedObserver == nil {
            msgReadDeliveredReactionFailedObserver = nc.addObserver(
                forName: .messageReadDeliveredFailedReaction,
                object: nil,
                queue: OperationQueue.main
            ) { [weak self] notification in
                self?.handleMsgReadDeliveredReactionFailed(notification)
            }
        }

        if incomingMsgObserver == nil {
            incomingMsgObserver = nc.addObserver(
                forName: eventIncomingMsg,
                object: nil, queue: OperationQueue.main
            ) { [weak self] notification in
                guard let self, let ui = notification.userInfo else { return }
                let chatId = ui["chat_id"] as? Int ?? 0
                if chatId == 0 || chatId == self.chatId {
                    let wasLastSectionScrolledToBottom = isLastRowScrolledToBottom()
                    refreshMessages()
                    updateTitle()
                    if wasLastSectionScrolledToBottom {
                        scrollToBottom(animated: true)
                    }
                    updateScrollDownButtonVisibility()
                    markSeenMessagesInVisibleArea()
                }
            }
        }

        if chatModifiedObserver == nil {
            chatModifiedObserver = nc.addObserver(
                forName: eventChatModified,
                object: nil,
                queue: OperationQueue.main
            ) { [weak self] notification in
                guard let self, let ui = notification.userInfo else { return }
                if self.chatId == ui["chat_id"] as? Int {
                    self.dcChat = self.dcContext.getChat(chatId: self.chatId)
                    if self.dcChat.canSend {
                        if self.messageInputBar.isHidden {
                            self.configureUIForWriting()
                            self.messageInputBar.isHidden = false
                            self.becomeFirstResponder()
                        }
                    } else if self.dcChat.isProtectionBroken {
                        self.configureContactRequestBar()
                        self.messageInputBar.isHidden = false
                        self.becomeFirstResponder()
                    } else if !self.dcChat.isContactRequest {
                        if !self.messageInputBar.isHidden {
                            self.messageInputBar.isHidden = true
                        }
                    }
                    self.updateTitle()
                }
            }
        }

        if ephemeralTimerModifiedObserver == nil {
            ephemeralTimerModifiedObserver = nc.addObserver(
                forName: eventEphemeralTimerModified,
                object: nil, queue: OperationQueue.main
            ) { [weak self] _ in
                guard let self else { return }
                self.updateTitle()
            }
        }

        nc.addObserver(self,
                       selector: #selector(applicationDidBecomeActive(_:)),
                       name: UIApplication.didBecomeActiveNotification,
                       object: nil)

        nc.addObserver(self,
                       selector: #selector(applicationWillResignActive(_:)),
                       name: UIApplication.willResignActiveNotification,
                       object: nil)
    }
    
    private func removeObservers() {
        let nc = NotificationCenter.default
        if let msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let msgReadDeliveredReactionFailedObserver {
            nc.removeObserver(msgReadDeliveredReactionFailedObserver)
        }
        if let incomingMsgObserver {
            nc.removeObserver(incomingMsgObserver)
        }
        if let chatModifiedObserver {
            nc.removeObserver(chatModifiedObserver)
        }
        if let ephemeralTimerModifiedObserver {
            nc.removeObserver(ephemeralTimerModifiedObserver)
        }

        nc.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        nc.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let lastSectionVisibleBeforeTransition = self.isLastRowVisible(checkTopCellPostion: true, checkBottomCellPosition: true, allowPartialVisibility: true)
        coordinator.animate(
            alongsideTransition: { [weak self] _ in
                guard let self else { return }
                self.navigationItem.setRightBarButton(self.badgeItem, animated: true)
                if lastSectionVisibleBeforeTransition {
                    self.scrollToBottom(animated: false)
                }
            },
            completion: {[weak self] _ in
                guard let self else { return }
                self.updateTitle()
                if lastSectionVisibleBeforeTransition {
                    DispatchQueue.main.async { [weak self] in
                        self?.reloadData()
                        self?.scrollToBottom(animated: false)
                    }
                }
            }
        )
        super.viewWillTransition(to: size, with: coordinator)
    }


    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            handleUserVisibility(isVisible: true)
        }
    }

    @objc func applicationWillResignActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            handleUserVisibility(isVisible: false)
            draft.save(context: dcContext)
        }
    }
    
    func handleUserVisibility(isVisible: Bool) {
        isVisibleToUser = isVisible
        if isVisible {
            startTimer()
            markSeenMessagesInVisibleArea()
        } else {
            stopTimer()
        }
    }

    /// UITableView methods
    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageIds.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        _ = handleUIMenu()

        let id = messageIds[indexPath.row]
        if id == DC_MSG_ID_DAYMARKER {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: InfoMessageCell.reuseIdentifier, for: indexPath) as? InfoMessageCell else {
                fatalError("WTF?! Wrong Cell, expected InfoMessageCell")
            }

            if messageIds.count > indexPath.row + 1 {
                var nextMessageId = messageIds[indexPath.row + 1]
                if nextMessageId == DC_MSG_ID_MARKER1 && messageIds.count > indexPath.row + 2 {
                    nextMessageId = messageIds[indexPath.row + 2]
                }

                let nextMessage = dcContext.getMessage(id: nextMessageId)
                cell.update(text: DateUtils.getDateString(date: nextMessage.sentDate), weight: .bold)
            } else {
                cell.update(text: "ErrDaymarker")
            }
            return cell
        } else if id == DC_MSG_ID_MARKER1 {
            // unread messages marker
            guard let cell = tableView.dequeueReusableCell(withIdentifier: InfoMessageCell.reuseIdentifier, for: indexPath) as? InfoMessageCell else {
                fatalError("WTF?! Wrong Cell, expected InfoMessageCell")
            }

            let freshMsgsCount = self.messageIds.count - (indexPath.row + 1)
            cell.update(text: String.localized(stringID: "chat_n_new_messages", parameter: freshMsgsCount))
            return cell
        }
        
        let message = dcContext.getMessage(id: id)
        if message.isInfo {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: InfoMessageCell.reuseIdentifier, for: indexPath) as? InfoMessageCell else {
                fatalError("WTF?! Wrong Cell, expected InfoMessageCell")
            }

            cell.showSelectionBackground(tableView.isEditing)
            if message.infoType == DC_INFO_WEBXDC_INFO_MESSAGE, let parent = message.parent {
                cell.update(text: message.text, image: parent.getWebxdcPreviewImage())
            } else {
                cell.update(text: message.text, infoType: message.infoType)
            }
            return cell
        }

        let cell: BaseMessageCell
        switch message.type {
        case DC_MSG_VIDEOCHAT_INVITATION:
            guard let videoInviteCell = tableView.dequeueReusableCell(withIdentifier: VideoInviteCell.reuseIdentifier, for: indexPath) as? VideoInviteCell
            else { fatalError("VideoInviteCell expected") }

            videoInviteCell.showSelectionBackground(tableView.isEditing)
            videoInviteCell.update(dcContext: dcContext, msg: message)
            return videoInviteCell

        case DC_MSG_IMAGE, DC_MSG_GIF, DC_MSG_VIDEO, DC_MSG_STICKER:
            guard let imageCell = tableView.dequeueReusableCell(withIdentifier: ImageTextCell.reuseIdentifier, for: indexPath) as? ImageTextCell else { fatalError("No ImageTextCell") }
            cell = imageCell

        case DC_MSG_FILE:
            if message.isSetupMessage {
                guard let textCell = tableView.dequeueReusableCell(withIdentifier: TextMessageCell.reuseIdentifier, for: indexPath) as? TextMessageCell else { fatalError("No TextMessageCell") }
                message.text = String.localized("autocrypt_asm_click_body")

                cell = textCell
            } else {
                guard let fileCell = tableView.dequeueReusableCell(withIdentifier: FileTextCell.reuseIdentifier, for: indexPath) as? FileTextCell else { fatalError("No FileTextCell") }

                cell = fileCell
            }
        case DC_MSG_WEBXDC:
            guard let xdcCell = tableView.dequeueReusableCell(withIdentifier: WebxdcCell.reuseIdentifier, for: indexPath) as? WebxdcCell else { fatalError("No WebxdcCell") }

            cell = xdcCell
        case DC_MSG_AUDIO, DC_MSG_VOICE:
            if message.isUnsupportedMediaFile {
                guard let fileCell = tableView.dequeueReusableCell(withIdentifier: FileTextCell.reuseIdentifier, for: indexPath) as? FileTextCell else { fatalError("No FileTextCell") }

                cell = fileCell
            } else {
                guard let audioMessageCell: AudioMessageCell = tableView.dequeueReusableCell(
                    withIdentifier: AudioMessageCell.reuseIdentifier,
                    for: indexPath) as? AudioMessageCell else { fatalError("No AudioMessageCell") }

                audioController.update(audioMessageCell, with: message.id)
                cell = audioMessageCell
            }
        case DC_MSG_VCARD:
            guard let contactCell = tableView.dequeueReusableCell(withIdentifier: ContactCardCell.reuseIdentifier, for: indexPath) as? ContactCardCell else { fatalError("No ContactCardCell") }

            cell = contactCell
        default:
            guard let textCell = tableView.dequeueReusableCell(withIdentifier: TextMessageCell.reuseIdentifier, for: indexPath) as? TextMessageCell else { fatalError("No TextMessageCell") }

            cell = textCell
        }

        var showAvatar = isGroupChat && !message.isFromCurrentSender
        var showName = isGroupChat
        if message.overrideSenderName != nil {
            showAvatar = !message.isFromCurrentSender
            showName = true
        }

        cell.baseDelegate = self
        cell.showSelectionBackground(tableView.isEditing)
        cell.update(dcContext: dcContext,
                    msg: message,
                    messageStyle: configureMessageStyle(for: message, at: indexPath),
                    showAvatar: showAvatar,
                    showName: showName,
                    searchText: searchController.searchBar.text,
                    highlight: !searchMessageIds.isEmpty && message.id == searchMessageIds[searchResultIndex])

        return cell
    }

    public override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            markSeenMessagesInVisibleArea()
            updateScrollDownButtonVisibility()
        }
    }

    public override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        markSeenMessagesInVisibleArea()
        updateScrollDownButtonVisibility()
    }

    override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        markSeenMessagesInVisibleArea()
        updateScrollDownButtonVisibility()
    }

    private func updateScrollDownButtonVisibility() {
        let scrollDownButtonHidden = contextMenuVisible || messageIds.isEmpty || isLastRowVisible(checkTopCellPostion: true,
                                                                                                  checkBottomCellPosition: true,
                                                                                                  allowPartialVisibility: true)
        
        messageInputBar.scrollDownButton.isHidden = scrollDownButtonHidden
    }

    private func configureContactRequestBar() {
        messageInputBar.separatorLine.backgroundColor = DcColors.colorDisabled
        shouldBecomeFirstResponder = true

        let bar: ChatContactRequestBar
        if dcChat.isProtectionBroken {
            bar = ChatContactRequestBar(.info, infoText: String.localizedStringWithFormat(String.localized("chat_protection_broken"), dcChat.name))
        } else {
            bar = ChatContactRequestBar(dcChat.isGroup && !dcChat.isMailinglist ? .delete : .block, infoText: nil)
        }
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        messageInputBar.setMiddleContentView(bar, animated: false)

        messageInputBar.setLeftStackViewWidthConstant(to: 0, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 0, animated: false)
        messageInputBar.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        messageInputBar.setStackViewItems([], forStack: .top, animated: false)
        messageInputBar.onScrollDownButtonPressed = scrollToBottom
        inputAccessoryView = messageInputBar
    }

    private func configureDraftArea(draft: DraftModel, animated: Bool = true) {
        if searchController.isActive {
            messageInputBar.setMiddleContentView(searchAccessoryBar, animated: false)
            messageInputBar.setLeftStackViewWidthConstant(to: 0, animated: false)
            messageInputBar.setRightStackViewWidthConstant(to: 0, animated: false)
            messageInputBar.setStackViewItems([], forStack: .top, animated: false)
            messageInputBar.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
            return
        }

        draftArea.configure(draft: draft)
        if draft.isEditing {
            inputAccessoryView = editingBar
            reloadInputViews()
        } else {
            inputAccessoryView = messageInputBar
            reloadInputViews()
            messageInputBar.setMiddleContentView(messageInputBar.inputTextView, animated: false)
            messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
            messageInputBar.setRightStackViewWidthConstant(to: 40, animated: false)
            messageInputBar.padding = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 12)
        }

        messageInputBar.setStackViewItems([draftArea], forStack: .top, animated: animated)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
       return UISwipeActionsConfiguration(actions: [])
    }


    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)
        if !canReply(to: message) {
            return nil
        }

        let action = UIContextualAction(style: .normal, title: nil,
                                        handler: { [weak self] (_, _, completionHandler) in
                                            self?.keepKeyboard = true
                                            self?.replyToMessage(at: indexPath)
                                            completionHandler(true)
                                        })
        if #available(iOS 13.0, *) {
            action.image = UIImage(systemName: "arrowshape.turn.up.left.fill")?.sd_tintedImage(with: DcColors.defaultInverseColor)
            action.backgroundColor = DcColors.chatBackgroundColor.withAlphaComponent(0.25)
        } else {
            action.image = UIImage(named: "ic_reply_black")
            action.backgroundColor = .systemBlue
        }
        action.accessibilityElements = nil
        let configuration = UISwipeActionsConfiguration(actions: [action])

        return configuration
    }

    func replyToMessage(at indexPath: IndexPath) {
        let message = dcContext.getMessage(id: self.messageIds[indexPath.row])
        self.draft.setQuote(quotedMsg: message)
        self.configureDraftArea(draft: self.draft)
        focusInputTextView()
    }

    func replyPrivatelyToMessage(at indexPath: IndexPath) {
        let msgId = self.messageIds[indexPath.row]
        let message = dcContext.getMessage(id: msgId)
        let privateChatId = dcContext.createChatByContactId(contactId: message.fromContactId)
        let replyMsg: DcMsg = dcContext.newMessage(viewType: DC_MSG_TEXT)
        replyMsg.quoteMessage = message
        dcContext.setDraft(chatId: privateChatId, message: replyMsg)
        showChat(chatId: privateChatId)
    }

    func markSeenMessagesInVisibleArea() {
        if isVisibleToUser,
           let indexPaths = tableView.indexPathsForVisibleRows {
                let visibleMessagesIds = indexPaths.map { UInt32(messageIds[$0.row]) }
                if !visibleMessagesIds.isEmpty {
                    DispatchQueue.global().async { [weak self] in
                        self?.dcContext.markSeenMessages(messageIds: visibleMessagesIds)
                    }
                }
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return tableView.cellForRow(at: indexPath) as? SelectableCell != nil
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let tableViewCell = tableView.cellForRow(at: indexPath)
        if let selectableCell = tableViewCell as? SelectableCell,
           !(tableView.isEditing &&
             tableViewCell as? InfoMessageCell != nil &&
             messageIds[indexPath.row] <= DC_MSG_ID_LAST_SPECIAL) {
            selectableCell.showSelectionBackground(tableView.isEditing)
            return indexPath
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            handleEditingBar()
            updateTitle()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            handleEditingBar()
            updateTitle()
            return
        }
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)
        if message.isSetupMessage {
            didTapAsm(msg: message, orgText: "")
        } else if message.type == DC_MSG_FILE ||
            message.type == DC_MSG_AUDIO ||
            message.type == DC_MSG_VOICE {
            showMediaGalleryFor(message: message)
        } else if message.type == DC_MSG_VIDEOCHAT_INVITATION {
            if let url = NSURL(string: message.getVideoChatUrl()) {
                UIApplication.shared.open(url as URL)
            }
        } else if message.type == DC_MSG_VCARD {
            didTapVcard(msg: message)
        } else if message.isInfo {
            switch message.infoType {
            case DC_INFO_WEBXDC_INFO_MESSAGE:
                if let parent = message.parent {
                    scrollToMessage(msgId: parent.id)
                }
            case DC_INFO_PROTECTION_ENABLED:
                showProtectionEnabledDialog()
            case DC_INFO_PROTECTION_DISABLED:
                showProtectionBrokenDialog()
            case DC_INFO_INVALID_UNENCRYPTED_MAIL:
                showInvalidUnencryptedDialog()
            default:
                break
            }
        }
        _ = handleUIMenu()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        messageInputBar.inputTextView.layer.borderColor = DcColors.colorDisabled.cgColor
        if #available(iOS 12.0, *),
            UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName) == nil {
            backgroundContainer.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
        }
    }

    private func configureMessageStyle(for message: DcMsg, at indexPath: IndexPath) -> UIRectCorner {
        var corners: UIRectCorner = []
        if message.isFromCurrentSender {
            corners.formUnion(.topLeft)
            corners.formUnion(.bottomLeft)
            corners.formUnion(.topRight)
        } else {
            corners.formUnion(.topRight)
            corners.formUnion(.bottomRight)
            corners.formUnion(.topLeft)
        }
        return corners
    }

    private func updateTitle() {
        titleView.translatesAutoresizingMaskIntoConstraints = false
        
        if tableView.isEditing {
            navigationItem.titleView = nil
            let cnt = tableView.indexPathsForSelectedRows?.count ?? 0
            navigationItem.title = String.localized(stringID: "n_selected", parameter: cnt)
            self.navigationItem.setLeftBarButton(cancelButton, animated: true)
        } else {
            let subtitle: String?
            let chatContactIds = dcChat.getContactIds(dcContext)
            if dcChat.isMailinglist {
                subtitle = String.localized("mailing_list")
            } else if dcChat.isBroadcast {
                subtitle = String.localized(stringID: "n_recipients", parameter: chatContactIds.count)
            } else if dcChat.isGroup {
                subtitle = String.localized(stringID: "n_members", parameter: chatContactIds.count)
            } else if dcChat.isDeviceTalk {
                subtitle = String.localized("device_talk_subtitle")
            } else if dcChat.isSelfTalk {
                subtitle = String.localized("chat_self_talk_subtitle")
            } else if !dcChat.isProtected && chatContactIds.count >= 1 {
                subtitle = dcContext.getContact(id: chatContactIds[0]).email
            } else {
                subtitle = nil
            }

            titleView.updateTitleView(title: dcChat.name, subtitle: subtitle, isVerified: dcChat.isProtected)
            titleView.layoutIfNeeded()
            navigationItem.titleView = titleView
            self.navigationItem.setLeftBarButton(nil, animated: true)
        }

        if let image = dcChat.profileImage {
            initialsBadge.setImage(image)
        } else {
            initialsBadge.setName(dcChat.name)
            initialsBadge.setColor(dcChat.color)
        }

        let recentlySeen = DcUtils.showRecentlySeen(context: dcContext, chat: dcChat)
        initialsBadge.setRecentlySeen(recentlySeen)

        var rightBarButtonItems = [badgeItem]
        if dcChat.isSendingLocations {
            rightBarButtonItems.append(locationStreamingItem)
        }
        if dcChat.isMuted {
            rightBarButtonItems.append(muteItem)
        }

        if dcContext.getChatEphemeralTimer(chatId: dcChat.id) > 0 {
            rightBarButtonItems.append(ephemeralMessageItem)
        }

        navigationItem.rightBarButtonItems = rightBarButtonItems
    }

    @objc
    private func refreshMessages() {
        self.messageIds = dcContext.getChatMsgs(chatId: chatId)
        let wasLastSectionScrolledToBottom = isLastRowScrolledToBottom()
        self.reloadData()
        if wasLastSectionScrolledToBottom {
            self.scrollToBottom(animated: true)
        }
        self.showEmptyStateView(self.messageIds.isEmpty)
    }

    private func reloadData() {
        let selectedRows = tableView.indexPathsForSelectedRows
        tableView.reloadData()
        selectedRows?.forEach({ (selectedRow) in
            tableView.selectRow(at: selectedRow, animated: false, scrollPosition: .none)
        })
    }

    private func loadMessages() {
        // update message ids
        var msgIds = dcContext.getChatMsgs(chatId: chatId)
        let freshMsgsCount = self.dcContext.getUnreadMessages(chatId: self.chatId)
        if freshMsgsCount > 0 && msgIds.count >= freshMsgsCount {
            let index = msgIds.count - freshMsgsCount
            msgIds.insert(Int(DC_MSG_ID_MARKER1), at: index)
        }
        self.messageIds = msgIds

        self.showEmptyStateView(self.messageIds.isEmpty)
        self.reloadData()
    }

    private func canReply(to message: DcMsg) -> Bool {
        return message.id != DC_MSG_ID_MARKER1 && message.id != DC_MSG_ID_DAYMARKER && !message.isInfo && message.type != DC_MSG_VIDEOCHAT_INVITATION && dcChat.canSend
    }

    private func canReplyPrivately(to message: DcMsg) -> Bool {
        return dcChat.isGroup && !message.isFromCurrentSender
    }

    private func isLastRowScrolledToBottom() -> Bool {
        return isLastRowVisible(checkTopCellPostion: false, checkBottomCellPosition: true)
    }

    // verifies if the last message cell is visible
    // - ommitting the parameters results in a simple check if the last message cell is preloaded. In that case it is not guaranteed that the cell is actually visible to the user and not covered e.g. by the messageInputBar
    // - if set to true, checkTopCellPosition verifies if the top of the last message cell is visible to the user
    // - if set to true, checkBottomCellPosition verifies if the bottom of the last message cell is visible to the user
    // - if set to true, allowPartialVisiblity ensures that any part of the last message shown in the visible area results in a true return value.
    // Using this flag large messages exceeding actual screen space are handled gracefully. This flag is only taken into account if checkTopCellPostion and checkBottomCellPosition are both set to true
    private func isLastRowVisible(checkTopCellPostion: Bool = false, checkBottomCellPosition: Bool = false, allowPartialVisibility: Bool = false) -> Bool {
        guard !messageIds.isEmpty else { return false }
        let lastIndexPath = IndexPath(item: messageIds.count - 1, section: 0)
        if !(checkTopCellPostion || checkBottomCellPosition) {
            return tableView.indexPathsForVisibleRows?.contains(lastIndexPath) ?? false
        }
        guard let window = UIApplication.shared.keyWindow else {
            return tableView.indexPathsForVisibleRows?.contains(lastIndexPath) ?? false
        }

        let rectOfCellInTableView = tableView.rectForRow(at: lastIndexPath)
        // convert points to same coordination system
        let inputBarTopInWindow = window.bounds.maxY - (messageInputBar.intrinsicContentSize.height + messageInputBar.keyboardHeight)
        var cellTopInWindow = tableView.convert(CGPoint(x: 0, y: rectOfCellInTableView.minY), to: window)
        cellTopInWindow.y = floor(cellTopInWindow.y)
        var cellBottomInWindow = tableView.convert(CGPoint(x: 0, y: rectOfCellInTableView.maxY), to: window)
        cellBottomInWindow.y = floor(cellBottomInWindow.y)
        let tableViewTopInWindow = tableView.convert(CGPoint(x: 0, y: tableView.bounds.minY), to: window)
        // check if top and bottom of the message are within the visible area
        let isTopVisible = cellTopInWindow.y < inputBarTopInWindow && cellTopInWindow.y >= tableViewTopInWindow.y
        let isBottomVisible = cellBottomInWindow.y <= inputBarTopInWindow && cellBottomInWindow.y >= tableViewTopInWindow.y
        // check if the message is visible, but top and bottom of cell exceed visible area
        let messageExceedsScreen = cellTopInWindow.y < tableViewTopInWindow.y && cellBottomInWindow.y > inputBarTopInWindow
        if checkTopCellPostion && checkBottomCellPosition {
            return allowPartialVisibility ?
            isTopVisible || isBottomVisible || messageExceedsScreen :
            isTopVisible && isBottomVisible
        } else if checkTopCellPostion {
            return isTopVisible
        } else {
            // checkBottomCellPosition
            return isBottomVisible
        }

    }
    
    private func scrollToBottom() {
        scrollToBottom(animated: true)
    }
    
    private func scrollToBottom(animated: Bool, focusOnVoiceOver: Bool = false) {
        if !messageIds.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let numberOfRows = self.tableView.numberOfRows(inSection: 0)
                if numberOfRows > 0 {
                    self.scrollToRow(at: IndexPath(row: numberOfRows - 1, section: 0),
                                     animated: animated,
                                     focusWithVoiceOver: focusOnVoiceOver)
                }
            }
        }
    }

    private func scrollToLastUnseenMessage(animated: Bool = false) {
        if let markerMessageIndex = self.messageIds.firstIndex(of: Int(DC_MSG_ID_MARKER1)) {
            let indexPath = IndexPath(row: markerMessageIndex, section: 0)
            self.scrollToRow(at: indexPath, animated: animated)
        } else {
            // scroll to bottom
            let numberOfRows = self.tableView.numberOfRows(inSection: 0)
            if numberOfRows > 0 {
                self.scrollToRow(at: IndexPath(row: numberOfRows - 1, section: 0), animated: animated)
            }
        }
    }

    private func scrollToMessage(msgId: Int, animated: Bool = true, scrollToText: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let index = self.messageIds.firstIndex(of: msgId) else {
                return
            }
            let indexPath = IndexPath(row: index, section: 0)

            if scrollToText && !UIAccessibility.isVoiceOverRunning {
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
                let cell = self.tableView.cellForRow(at: indexPath)
                if let messageCell = cell as? BaseMessageCell {
                    let textYPos = messageCell.getTextOffset(of: self.searchController.searchBar.text)
                    let currentYPos = self.tableView.contentOffset.y
                    let padding: CGFloat = 12
                    self.tableView.setContentOffset(CGPoint(x: 0,
                                                            y: textYPos +
                                                                currentYPos -
                                                                2 * UIFont.preferredFont(for: .body, weight: .regular).lineHeight -
                                                                padding),
                                                    animated: false)

                    return
                }
            }

            self.scrollToRow(at: indexPath, animated: false)
        }
    }

    private func scrollToRow(at indexPath: IndexPath, animated: Bool, focusWithVoiceOver: Bool = true) {
        if UIAccessibility.isVoiceOverRunning && focusWithVoiceOver {
            tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            markSeenMessagesInVisibleArea()
            updateScrollDownButtonVisibility()
            forceVoiceOverFocussingCell(at: indexPath) { [weak self] in
                self?.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
            }
        } else {
            tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
        }
    }

    // VoiceOver tends to jump and read out the top visible cell within the tableView if we
    // don't force it to refocus the cell we're interested in. Posting multiple times a .layoutChanged
    // notification doesn't cause VoiceOver to readout the cell mutliple times.
    private func forceVoiceOverFocussingCell(at indexPath: IndexPath, postingFinished: (() -> Void)?) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            for _ in 1...4 {
                DispatchQueue.main.async {
                    UIAccessibility.post(notification: .layoutChanged, argument: self.tableView.cellForRow(at: indexPath))
                    postingFinished?()
                }
                usleep(500_000)
            }
        }
    }

    private func showEmptyStateView(_ show: Bool) {
        if show {
            if dcChat.isGroup {
                if dcChat.isBroadcast {
                    emptyStateView.text = String.localized("chat_new_broadcast_hint")
                } else if dcChat.isUnpromoted {
                    emptyStateView.text = String.localized("chat_new_group_hint")
                } else {
                    emptyStateView.text = String.localized("chat_no_messages")
                }
            } else if dcChat.isSelfTalk {
                emptyStateView.text = String.localized("saved_messages_explain")
            } else if dcChat.isDeviceTalk {
                emptyStateView.text = String.localized("device_talk_explain")
            } else {
                emptyStateView.text = String.localizedStringWithFormat(String.localized("chat_new_one_to_one_hint"), dcChat.name)
            }
            emptyStateView.isHidden = false
        } else {
            emptyStateView.isHidden = true
        }
    }

    @objc private func saveDraft() {
        draft.save(context: dcContext)
    }

    private func configureMessageInputBar() {
        messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.placeholder = String.localized("chat_input_placeholder")
        messageInputBar.inputTextView.accessibilityLabel = String.localized("write_message_desktop")
        messageInputBar.separatorLine.backgroundColor = DcColors.colorDisabled
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.textColor = DcColors.defaultTextColor
        messageInputBar.inputTextView.backgroundColor = DcColors.inputFieldColor
        messageInputBar.inputTextView.placeholderTextColor = DcColors.placeholderColor
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 38)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 38)
        messageInputBar.inputTextView.layer.borderColor = DcColors.colorDisabled.cgColor
        messageInputBar.inputTextView.layer.borderWidth = 1.0
        messageInputBar.inputTextView.layer.cornerRadius = 13.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        configureInputBarItems()
        messageInputBar.inputTextView.delegate = self
        messageInputBar.inputTextView.imagePasteDelegate = self
        messageInputBar.onScrollDownButtonPressed = scrollToBottom
        messageInputBar.inputTextView.setDropInteractionDelegate(delegate: self)
        messageInputBar.isTranslucent = true
    }

    private func evaluateInputBar(draft: DraftModel) {
        messageInputBar.sendButton.isEnabled = draft.canSend()
        messageInputBar.sendButton.accessibilityTraits = draft.canSend() ? .button : .notEnabled
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
        messageInputBar.shouldManageSendButtonEnabledState = false

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
                self?.messageInputBar.inputTextView.resignFirstResponder()
                self?.clipperButtonPressed()
            }
        ]

        messageInputBar.setStackViewItems(leftItems, forStack: .left, animated: false)

        // This just adds some more flare
        messageInputBar.sendButton
            .onEnabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.primary
                })}
            .onDisabled { item in
                UIView.animate(withDuration: 0.3, animations: {
                    item.backgroundColor = DcColors.colorDisabled
                })}
    }

    @objc private func chatProfilePressed() {
        if tableView.isEditing {
            return
        }
        titleView.setEnabled(false) // immedidate feedback
        DispatchQueue.main.async { // opening controller in next loop allows the system to render the immedidate feedback
            self.showChatDetail(chatId: self.chatId)
            self.titleView.setEnabled(true)
        }
    }

    @objc private func clipperButtonPressed() {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .safeActionSheet)
        let galleryAction = PhotoPickerAlertAction(title: String.localized("gallery"), style: .default, handler: galleryButtonPressed(_:))
        let cameraAction = PhotoPickerAlertAction(title: String.localized("camera"), style: .default, handler: cameraButtonPressed(_:))
        let documentAction = UIAlertAction(title: String.localized("files"), style: .default, handler: documentActionPressed(_:))
        let voiceMessageAction = UIAlertAction(title: String.localized("voice_message"), style: .default, handler: voiceMessageButtonPressed(_:))
        let sendContactAction = UIAlertAction(title: String.localized("contact"), style: .default, handler: showContactList(_:))
        let isLocationStreaming = dcContext.isSendingLocationsToChat(chatId: chatId)
        let locationStreamingAction = UIAlertAction(title: isLocationStreaming ? String.localized("stop_sharing_location") : String.localized("location"),
                                                    style: isLocationStreaming ? .destructive : .default,
                                                    handler: locationStreamingButtonPressed(_:))

        alert.addAction(cameraAction)
        alert.addAction(galleryAction)
        alert.addAction(documentAction)

        if dcContext.hasWebxdc(chatId: 0) {
            let webxdcAction = UIAlertAction(title: String.localized("webxdc_apps"), style: .default, handler: webxdcButtonPressed(_:))
            alert.addAction(webxdcAction)
        }
        
        alert.addAction(voiceMessageAction)

        if let config = dcContext.getConfig("webrtc_instance"), !config.isEmpty {
            let videoChatInvitation = UIAlertAction(title: String.localized("videochat"), style: .default, handler: videoChatButtonPressed(_:))
            alert.addAction(videoChatInvitation)
        }

        if UserDefaults.standard.bool(forKey: "location_streaming") {
            alert.addAction(locationStreamingAction)
        }

        alert.addAction(sendContactAction)

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in self.shouldBecomeFirstResponder = true }))

        shouldBecomeFirstResponder = false
        messageInputBar.inputTextView.resignFirstResponder()

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

    private func showMoreMenu() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .safeActionSheet)
        if canResend() {
            alert.addAction(UIAlertAction(title: String.localized("resend"), style: .default, handler: onResendActionPressed(_:)))
        }
        if canShare() {
            alert.addAction(UIAlertAction(title: String.localized("menu_share"), style: .default, handler: onShareActionPressed(_:)))
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func onResendActionPressed(_ action: UIAlertAction) {
        if let rows = tableView.indexPathsForSelectedRows {
            let selectedMsgIds = rows.compactMap { messageIds[$0.row] }
            dcContext.resendMessages(msgIds: selectedMsgIds)
            setEditing(isEditing: false)
        }
    }

    private func onShareActionPressed(_ action: UIAlertAction) {
        if let rows = tableView.indexPathsForSelectedRows {
            let selectedMsgIds = rows.compactMap { messageIds[$0.row] }
            if let msgId = selectedMsgIds.first {
                Utils.share(message: dcContext.getMessage(id: msgId), parentViewController: self, sourceView: self.view)
                setEditing(isEditing: false)
            }
        }
    }

    private func askToDeleteChat() {
        let title = String.localized(stringID: "ask_delete_chat", parameter: 1)
        confirmationAlert(title: title, actionTitle: String.localized("delete"), actionStyle: .destructive,
                          actionHandler: { [weak self] _ in
                            guard let self else { return }
                            // remove message observers early to avoid careless calls to dcContext methods
                            self.removeObservers()
                            self.dcContext.deleteChat(chatId: self.chatId)
                            self.navigationController?.popViewController(animated: true)
                          })
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
        self.askToDeleteMessages(ids: [id])
    }

    private func askToDeleteMessages(ids: [Int]) {
        let chat = dcContext.getChat(chatId: chatId)
        let title = chat.isDeviceTalk ?
            String.localized(stringID: "ask_delete_messages_simple", parameter: ids.count) :
            String.localized(stringID: "ask_delete_messages", parameter: ids.count)
        confirmationAlert(title: title, actionTitle: String.localized("delete"), actionStyle: .destructive,
                          actionHandler: { _ in
                            self.dcContext.deleteMessages(msgIds: ids)
                            if self.tableView.isEditing {
                                self.setEditing(isEditing: false)
                            }
                          })
    }

    private func askToForwardMessage() {
        let chat = dcContext.getChat(chatId: self.chatId)
        if chat.isSelfTalk {
            RelayHelper.shared.forwardIdsAndFinishRelaying(to: self.chatId)
            refreshMessages()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.confirmationAlert(title: String.localizedStringWithFormat(String.localized("ask_forward"), chat.name),
                                        actionTitle: String.localized("menu_forward"),
                                        actionHandler: { [weak self] _ in
                                            guard let self else { return }
                                            RelayHelper.shared.forwardIdsAndFinishRelaying(to: self.chatId)
                                        },
                                        cancelHandler: { [weak self] _ in
                                            self?.navigationController?.popViewController(animated: true)
                                        })
            }
        }
    }

    // MARK: - coordinator
    private func showChatDetail(chatId: Int) {
        let chat = dcContext.getChat(chatId: chatId)
        if !chat.isGroup {
            if let contactId = chat.getContactIds(dcContext).first {
                let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: contactId)
                navigationController?.pushViewController(contactDetailController, animated: true)
            }
        } else {
            let groupChatDetailViewController = GroupChatDetailViewController(chatId: chatId, dcContext: dcContext)
            navigationController?.pushViewController(groupChatDetailViewController, animated: true)
        }
    }

    func showChat(chatId: Int, messageId: Int? = nil, animated: Bool = true) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId, msgId: messageId, animated: animated, clearViewControllerStack: true)
        }
    }

    private func showWebxdcSelector() {
        let webxdcSelector = WebxdcSelector(context: dcContext)
        webxdcSelector.delegate = self
        let webxdcSelectorNavigationController = UINavigationController(rootViewController: webxdcSelector)
        if #available(iOS 15.0, *) {
            if let sheet = webxdcSelectorNavigationController.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.preferredCornerRadius = 20
            }
        }

        self.present(webxdcSelectorNavigationController, animated: true)
    }

    private func showDocumentLibrary() {
        mediaPicker?.showDocumentLibrary()
    }

    private func showVoiceMessageRecorder() {
        mediaPicker?.showVoiceRecorder()
    }

    private func showCameraViewController() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            self.mediaPicker?.showCamera()
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    if granted {
                        self.mediaPicker?.showCamera()
                    } else {
                        self.showCameraPermissionAlert()
                    }
                }
            })
        }
    }
    
    private func showCameraPermissionAlert() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: String.localized("perm_required_title"),
                                          message: String.localized("perm_ios_explain_access_to_camera_denied"),
                                          preferredStyle: .alert)
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                alert.addAction(UIAlertAction(title: String.localized("open_settings"), style: .default, handler: { _ in
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)}))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .destructive, handler: nil))
            }
            self?.present(alert, animated: true, completion: nil)
        }
    }

    private func showPhotoVideoLibrary(delegate: MediaPickerDelegate) {
        mediaPicker?.showPhotoVideoLibrary()
    }

    private func showProtectionBrokenDialog() {
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("chat_protection_broken_explanation"), dcChat.name), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("learn_more"), style: .default, handler: { _ in
            self.navigationController?.pushViewController(HelpViewController(dcContext: self.dcContext, fragment: "#nocryptanymore"), animated: true)
        }))
        alert.addAction(UIAlertAction(title: String.localized("qrscan_title"), style: .default, handler: { _ in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.appCoordinator.presentQrCodeController()
            }
        }))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func showProtectionEnabledDialog() {
        let alert = UIAlertController(title: String.localized("chat_protection_enabled_explanation"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("learn_more"), style: .default, handler: { _ in
            self.navigationController?.pushViewController(HelpViewController(dcContext: self.dcContext, fragment: "#e2eeguarantee"), animated: true)
        }))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func showInvalidUnencryptedDialog() {
        let alert = UIAlertController(title: String.localized("invalid_unencrypted_explanation"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("learn_more"), style: .default, handler: { _ in
            self.navigationController?.pushViewController(HelpViewController(dcContext: self.dcContext, fragment: "#howtoe2ee"), animated: true)
        }))
        alert.addAction(UIAlertAction(title: String.localized("qrscan_title"), style: .default, handler: { _ in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.appCoordinator.presentQrCodeController()
            }
        }))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func webxdcButtonPressed(_ action: UIAlertAction) {
        shouldBecomeFirstResponder = true
        showWebxdcSelector()
    }

    private func documentActionPressed(_ action: UIAlertAction) {
        shouldBecomeFirstResponder = true
        showDocumentLibrary()
    }

    private func voiceMessageButtonPressed(_ action: UIAlertAction) {
        shouldBecomeFirstResponder = true
        showVoiceMessageRecorder()
    }

    private func cameraButtonPressed(_ action: UIAlertAction) {
        showCameraViewController()
    }

    private func galleryButtonPressed(_ action: UIAlertAction) {
        shouldBecomeFirstResponder = true
        showPhotoVideoLibrary(delegate: self)
    }

    private func showContactList(_ action: UIAlertAction) {
        shouldBecomeFirstResponder = true

        let contactList = SendContactViewController(dcContext: dcContext)
        contactList.delegate = self

        let navigationController = UINavigationController(rootViewController: contactList)
        if #available(iOS 15.0, *) {
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.large(), .medium()]
                sheet.preferredCornerRadius = 20
            }
        }

        present(navigationController, animated: true)
    }

    private func locationStreamingButtonPressed(_ action: UIAlertAction) {
        shouldBecomeFirstResponder = true
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

    private func videoChatButtonPressed(_ action: UIAlertAction) {
        let chat = dcContext.getChat(chatId: chatId)

        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("videochat_invite_user_to_videochat"), chat.name),
                                      message: String.localized("videochat_invite_user_hint"),
                                      preferredStyle: .alert)
        let cancel = UIAlertAction(title: String.localized("cancel"), style: .default, handler: nil)
        let ok = UIAlertAction(title: String.localized("ok"),
                               style: .default,
                               handler: { _ in
                                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                                    guard let self else { return }
                                    let messageId = self.dcContext.sendVideoChatInvitation(chatId: self.chatId)
                                    let inviteMessage = self.dcContext.getMessage(id: messageId)
                                    if let url = NSURL(string: inviteMessage.getVideoChatUrl()) {
                                        DispatchQueue.main.async {
                                            UIApplication.shared.open(url as URL)
                                        }
                                    }
                                }})
        alert.addAction(cancel)
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
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
        if !appDelegate.locationManager.shareLocation(chatId: self.chatId, duration: seconds) {
            let alert = UIAlertController(title: String.localized("location_denied"), message: String.localized("location_denied_explain_ios"), preferredStyle: .alert)
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                alert.addAction(UIAlertAction(title: String.localized("open_settings"), style: .default, handler: { _ in
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                }))
            }
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            navigationController?.present(alert, animated: true, completion: nil)
        }
    }

    private func sendTextMessage(text: String, quoteMessage: DcMsg?) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let message = self.dcContext.newMessage(viewType: DC_MSG_TEXT)
            message.text = text
            if let quoteMessage {
                message.quoteMessage = quoteMessage
            }
            self.dcContext.sendMessage(chatId: self.chatId, message: message)
        }
    }

    private func focusInputTextView() {
        shouldBecomeFirstResponder = true
        becomeFirstResponder()
        messageInputBar.inputTextView.becomeFirstResponder()
        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
                UIAccessibility.post(notification: .layoutChanged, argument: self?.messageInputBar.inputTextView)
            })
        }
    }

    private func stageVCard(url: URL) {
        keepKeyboard = true

        draft.setAttachment(viewType: DC_MSG_VCARD, path: url.relativePath)
        configureDraftArea(draft: draft)
        focusInputTextView()
        FileHelper.deleteFile(atPath: url.relativePath)
    }

    private func stageDocument(url: NSURL) {
        keepKeyboard = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.draft.setAttachment(viewType: url.pathExtension == "xdc" ? DC_MSG_WEBXDC : DC_MSG_FILE, path: url.relativePath)
            self.configureDraftArea(draft: self.draft)
            self.focusInputTextView()
            FileHelper.deleteFile(atPath: url.relativePath)
        }
    }

    private func stageVideo(url: NSURL) {
        keepKeyboard = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.draft.setAttachment(viewType: DC_MSG_VIDEO, path: url.relativePath)
            self.configureDraftArea(draft: self.draft)
            self.focusInputTextView()
            FileHelper.deleteFile(atPath: url.relativePath)
        }
    }

    private func stageImage(url: NSURL) {
        keepKeyboard = true
        DispatchQueue.global().async { [weak self] in
            if let image = ImageFormat.loadImageFrom(url: url as URL) {
                self?.stageImage(image)
            }
        }
    }

    private func stageImage(_ image: UIImage) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if let pathInCachesDir = ImageFormat.saveImage(image: image, directory: .cachesDirectory) {
                DispatchQueue.main.async {
                    if pathInCachesDir.suffix(4).contains(".gif") {
                        self.draft.setAttachment(viewType: DC_MSG_GIF, path: pathInCachesDir)
                    } else {
                        self.draft.setAttachment(viewType: DC_MSG_IMAGE, path: pathInCachesDir)
                    }
                    self.configureDraftArea(draft: self.draft)
                    self.focusInputTextView()
                    FileHelper.deleteFile(atPath: pathInCachesDir)
                }
            }
        }
    }

    private func sendImage(_ image: UIImage, message: String? = nil) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if let path = ImageFormat.saveImage(image: image, directory: .cachesDirectory) {
                self.sendAttachmentMessage(viewType: DC_MSG_IMAGE, filePath: path, message: message)
                FileHelper.deleteFile(atPath: path)
            }
        }
    }

    private func sendSticker(_ image: UIImage) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if let path = ImageFormat.saveImage(image: image, directory: .cachesDirectory) {
                self.sendAttachmentMessage(viewType: DC_MSG_STICKER, filePath: path, message: nil)
                FileHelper.deleteFile(atPath: path)
            }
        }
    }

    private func sendAttachmentMessage(viewType: Int32, filePath: String, message: String? = nil, quoteMessage: DcMsg? = nil) {
        let msg = draft.draftMsg ?? dcContext.newMessage(viewType: viewType)
        msg.setFile(filepath: filePath)
        msg.text = (message ?? "").isEmpty ? nil : message
        if quoteMessage != nil {
            msg.quoteMessage = quoteMessage
        }
        dcContext.sendMessage(chatId: self.chatId, message: msg)
    }

    private func sendVoiceMessage(url: NSURL) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let msg = self.dcContext.newMessage(viewType: DC_MSG_VOICE)
            if let quoteMessage =  self.draft.quoteMessage {
                msg.quoteMessage = quoteMessage
            }
            msg.setFile(filepath: url.relativePath, mimeType: "audio/m4a")
            self.dcContext.sendMessage(chatId: self.chatId, message: msg)
            DispatchQueue.main.async {
                self.draft.setQuote(quotedMsg: nil)
                self.draftArea.quotePreview.cancel()
            }
        }
    }

    // MARK: - Actions

    @objc private func info(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        info(at: indexPath)
    }

    private func info(at indexPath: IndexPath) {
        let msg = self.dcContext.getMessage(id: self.messageIds[indexPath.row])
        let msgViewController = MessageInfoViewController(dcContext: self.dcContext, message: msg)
        if let ctrl = self.navigationController {
            ctrl.pushViewController(msgViewController, animated: true)
        }
    }

    @objc private func forward(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        forward(at: indexPath)
    }

    private func forward(at indexPath: IndexPath) {
        let msg = dcContext.getMessage(id: messageIds[indexPath.row])
        RelayHelper.shared.setForwardMessage(messageId: msg.id)
        navigationController?.popViewController(animated: true)
    }

    @objc private func reply(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        reply(at: indexPath)
    }

    private func reply(at indexPath: IndexPath) {
        keepKeyboard = true
        replyToMessage(at: indexPath)
    }

    private func copyToClipboard(at indexPath: IndexPath) {
        copyToClipboard(ids: [self.messageIds[indexPath.row]])
    }

    @objc private func replyPrivately(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        replyPrivatelyToMessage(at: indexPath)
    }

    @objc private func selectMore(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        selectMore(at: indexPath)
    }

    private func selectMore(at indexPath: IndexPath) {
        messageInputBar.inputTextView.resignFirstResponder()
        resignFirstResponder()

        setEditing(isEditing: true, selectedAtIndexPath: indexPath)
        if UIAccessibility.isVoiceOverRunning {
            forceVoiceOverFocussingCell(at: indexPath, postingFinished: nil)
        }
    }

    @objc private func react(_ sender: Any) {
        guard let menuItem = UIMenuController.shared.menuItems?.first as? LegacyMenuItem,
              let indexPath = menuItem.indexPath else { return }

        reactionMessageId = self.messageIds[indexPath.row]

        let pickerViewController = MCEmojiPickerViewController()
        pickerViewController.navigationItem.title = String.localized("react")
        pickerViewController.delegate = self

        let navigationController = UINavigationController(rootViewController: pickerViewController)
        present(navigationController, animated: true)

    }

    // MARK: - UIMenuItems (< iOS 13)
    private func contextMenu(for indexPath: IndexPath) -> [LegacyMenuItem] {
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)

        var menu: [LegacyMenuItem] = []

        if canReply(to: message) {
            menu.append(LegacyMenuItem(title: String.localized("react"), action: #selector(ChatViewController.react(_:)), indexPath: indexPath))
            menu.append(LegacyMenuItem(title: String.localized("notify_reply_button"), action: #selector(ChatViewController.reply(_:)), indexPath: indexPath))
        }

        if canReplyPrivately(to: message) {
            menu.append(LegacyMenuItem(title: String.localized("reply_privately"), action: #selector(ChatViewController.replyPrivately(_:)), indexPath: indexPath))
        }

        menu.append(contentsOf: [
            LegacyMenuItem(title: String.localized("forward"), action: #selector(ChatViewController.forward(_:)), indexPath: indexPath),
            LegacyMenuItem(title: String.localized("info"), action: #selector(ChatViewController.info(_:)), indexPath: indexPath),
            LegacyMenuItem(title: String.localized("menu_more_options"), action: #selector(ChatViewController.selectMore(_:)), indexPath: indexPath)
        ])

        return menu
    }

    private func prepareContextMenu(isHidden: Bool, indexPath: IndexPath) {

        if #available(iOS 13.0, *) {
            return
        }

        guard let rect = tableView.cellForRow(at: indexPath)?.frame else { return }
        UIMenuController.shared.setTargetRect(rect, in: tableView)

        if isHidden {
            UIMenuController.shared.menuItems = nil
            UIMenuController.shared.isMenuVisible = false
        } else {
            UIMenuController.shared.menuItems = contextMenu(for: indexPath)
            UIMenuController.shared.isMenuVisible = true
        }

        UIMenuController.shared.update()
        shouldBecomeFirstResponder = true
        becomeFirstResponder()
    }

    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        let messageId = messageIds[indexPath.row]
        let isHidden = messageId == DC_MSG_ID_MARKER1 || messageId == DC_MSG_ID_DAYMARKER
        prepareContextMenu(isHidden: isHidden, indexPath: indexPath)
        return !isHidden
    }

    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        let actionIsPartOfMenu = contextMenu(for: indexPath).compactMap { $0.action }.first { $0 == action } != nil

        return (tableView.isEditing == false) && actionIsPartOfMenu
    }

    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        // handle standard actions here, but custom actions never trigger this. it still needs to be present for the menu to display, though.
        // Does intentionally nothing.
    }


    @objc(tableView:canHandleDropSession:)
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return self.dropInteraction.dropInteraction(canHandle: session)
    }

    @objc
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return UITableViewDropProposal(operation: .copy)
    }

    @objc(tableView:performDropWithCoordinator:)
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        return self.dropInteraction.dropInteraction(performDrop: coordinator.session)
    }


    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let id = messageIds[indexPath.row]
        return id != DC_MSG_ID_DAYMARKER && id != DC_MSG_ID_MARKER1
    }
}

@available(iOS 13.0, *)
extension ChatViewController {

    override func tableView(_ tableView: UITableView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        guard let messageId = configuration.identifier as? NSString, let index = messageIds.firstIndex(of: messageId.integerValue) else { return }

        let indexPath = IndexPath(row: index, section: 0)

        guard let cell = tableView.cellForRow(at: indexPath) as? BaseMessageCell else { return }

        cell.messageBackgroundContainer.isHidden = true
        cell.reactionsView.isHidden = true
        contextMenuVisible = true

        updateScrollDownButtonVisibility()
    }

    override func tableView(_ tableView: UITableView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        guard let messageId = configuration.identifier as? NSString, let index = messageIds.firstIndex(of: messageId.integerValue) else {
            debugPrint("booooom")
            return
        }

        let indexPath = IndexPath(row: index, section: 0)
        guard let cell = tableView.cellForRow(at: indexPath) as? BaseMessageCell else { 
            debugPrint("booooom")
            return
        }

        cell.messageBackgroundContainer.isHidden = false
        cell.reactionsView.isHidden = false
        contextMenuVisible = false

        updateScrollDownButtonVisibility()
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return targetedPreview(for: configuration)
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return targetedPreview(for: configuration)
    }

    private func targetedPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let messageId = configuration.identifier as? NSString else { return nil }
        guard let index = messageIds.firstIndex(of: messageId.integerValue) else { return nil }
        let indexPath = IndexPath(row: index, section: 0)
        let message = dcContext.getMessage(id: messageId.integerValue)

        guard let cell = tableView.cellForRow(at: indexPath) as? BaseMessageCell,
              let messageSnapshotView = cell.messageBackgroundContainer.snapshotView(afterScreenUpdates: false) else { return nil }

        var centerPoint = cell.convert(cell.messageBackgroundContainer.frame.origin, to: tableView)
        centerPoint.y += 0.5 * cell.messageBackgroundContainer.frame.height

        if message.isFromCurrentSender {
            centerPoint.x = cell.frame.width - 0.5 * messageSnapshotView.frame.width - 6 - view.safeAreaInsets.right
        } else {
            centerPoint.x = messageSnapshotView.center.x + cell.messageBackgroundContainer.frame.minX + view.safeAreaInsets.left
        }

        let previewTarget = UIPreviewTarget(container: tableView, center: centerPoint)

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        let preview = UITargetedPreview(view: messageSnapshotView, parameters: parameters, target: previewTarget)

        return preview
    }

    private func appendReactionItems(to menuElements: inout [UIMenuElement], indexPath: IndexPath) {
        let messageId = messageIds[indexPath.row]
        let myReactions = getMyReactions(messageId: messageId)
        var myReactionChecked = false

        for reaction in DefaultReactions.allCases {
            let sentThisReaction = myReactions.contains(where: { $0 == reaction.emoji })
            let title: String
            if sentThisReaction {
                title = reaction.emoji + "✓"
                myReactionChecked = true
            } else {
                title = reaction.emoji
            }
            menuElements.append(UIAction(title: title) { [weak self] _ in
                guard let self else { return }

                let messageId = self.messageIds[indexPath.row]
                if sentThisReaction {
                    dcContext.sendReaction(messageId: messageId, reaction: nil)
                } else {
                    dcContext.sendReaction(messageId: messageId, reaction: reaction.emoji)
                }
            })
        }

        let showPicker = myReactions.isEmpty || myReactionChecked
        let title: String
        let accessibilityLabel: String?
        if showPicker {
            title = "•••"
            accessibilityLabel = String.localized("pref_other")
        } else {
            title = (myReactions.first ?? "?") + "✓"
            accessibilityLabel = nil
        }
        let action = UIAction(title: title) { [weak self] _ in
            guard let self else { return }
            let messageId = self.messageIds[indexPath.row]
            if showPicker {
                reactionMessageId = messageId
                let pickerViewController = MCEmojiPickerViewController()
                pickerViewController.navigationItem.title = String.localized("react")
                pickerViewController.delegate = self

                let navigationController = UINavigationController(rootViewController: pickerViewController)
                if #available(iOS 15.0, *) {
                    if let sheet = navigationController.sheetPresentationController {
                        sheet.detents = [.medium(), .large()]
                        sheet.preferredCornerRadius = 20
                    }
                }
                present(navigationController, animated: true)
            } else {
                dcContext.sendReaction(messageId: messageId, reaction: nil)
            }
        }
        action.accessibilityLabel = accessibilityLabel
        menuElements.append(action)
    }

    // context menu for iOS 13+
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let messageId = messageIds[indexPath.row]
        if tableView.isEditing || messageId == DC_MSG_ID_MARKER1 || messageId == DC_MSG_ID_DAYMARKER {
            return nil
        }

        return UIContextMenuConfiguration(
            identifier: NSString(string: "\(messageId)"),
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }
                let message = dcContext.getMessage(id: messageId)
                var children: [UIMenuElement] = []
                var preferredElementSizeSmall = false

                if canReply(to: message) {
                    if #available(iOS 16.0, *) {
                        appendReactionItems(to: &children, indexPath: indexPath)
                        preferredElementSizeSmall = true
                    } else {
                        var items: [UIMenuElement] = []
                        appendReactionItems(to: &items, indexPath: indexPath)
                        children.append(UIMenu(title: String.localized("react"), image: UIImage(systemName: "face.smiling"), children: items))
                    }
                    children.append(
                        UIAction.menuAction(localizationKey: "notify_reply_button", systemImageName: "arrowshape.turn.up.left.fill", indexPath: indexPath, action: { self.reply(at: $0 ) })
                    )
                }

                if canReplyPrivately(to: message) {
                    children.append(
                        UIAction.menuAction(localizationKey: "reply_privately", systemImageName: "arrowshape.turn.up.left", indexPath: indexPath, action: { self.replyPrivatelyToMessage(at: $0 ) })
                    )
                }

                children.append(
                    UIAction.menuAction(localizationKey: "forward", systemImageName: "arrowshape.forward.fill", indexPath: indexPath, action: { self.forward(at: $0 ) })
                )

                if let text = message.text, !text.isEmpty {
                    let copyTitle = message.file == nil ? "global_menu_edit_copy_desktop" : "menu_copy_text_to_clipboard"
                    children.append(
                        UIAction.menuAction(localizationKey: copyTitle, systemImageName: "doc.on.doc", indexPath: indexPath, action: { self.copyToClipboard(at: $0 ) })
                    )
                }

                children.append(contentsOf: [
                    UIAction.menuAction(localizationKey: "info", systemImageName: "info", indexPath: indexPath, action: { self.info(at: $0 ) }),
                    UIMenu(options: [.displayInline], children: [
                        UIAction.menuAction(localizationKey: "menu_more_options", systemImageName: "checkmark.circle", indexPath: indexPath, action: { self.selectMore(at: $0 ) }),
                    ])
                ])

                let menu = UIMenu(children: children)
                if preferredElementSizeSmall, #available(iOS 16.0, *) {
                    menu.preferredElementSize = .small
                }
                return menu
            }
        )
    }
}

extension ChatViewController: MCEmojiPickerDelegate {
    func didGetEmoji(emoji: String) {
        if let reactionMessageId {
            let sentThisReaction = getMyReactions(messageId: reactionMessageId).contains(where: { $0 == emoji })
            if sentThisReaction {
                dcContext.sendReaction(messageId: reactionMessageId, reaction: nil)
            } else {
                dcContext.sendReaction(messageId: reactionMessageId, reaction: emoji)
            }
        }
    }
}

extension ChatViewController {

    func showWebxdcViewFor(message: DcMsg) {
        let webxdcViewController = WebxdcViewController(dcContext: dcContext, messageId: message.id)
        navigationController?.pushViewController(webxdcViewController, animated: true)
    }

    func showMediaGalleryFor(message: DcMsg) {
        let msgIds = dcContext.getChatMedia(chatId: chatId, messageType: Int32(message.type), messageType2: 0, messageType3: 0)
        let index = msgIds.firstIndex(of: message.id) ?? 0

        navigationController?.pushViewController(PreviewController(dcContext: dcContext, type: .multi(msgIds, index)), animated: true)
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

    func didTapVcard(msg: DcMsg) {
        guard let file = msg.file,
              let vcards = dcContext.parseVcard(path: file),
              let vcard = vcards.first else { return }
        
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), vcard.displayName), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
            if let contactIds = self.dcContext.importVcard(path: file) {
                logger.info("imported contacts: \(contactIds)")
                if let contactId = contactIds.first {
                    let chatId = self.dcContext.createChatByContactId(contactId: contactId)
                    self.showChat(chatId: chatId)
                }
            }
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func handleUIMenu() -> Bool {
        if UIMenuController.shared.isMenuVisible {
            UIMenuController.shared.setMenuVisible(false, animated: true)
            return true
        }
        return false
    }

    func handleSelection(indexPath: IndexPath) -> Bool {
        if tableView.isEditing {
            if tableView.indexPathsForSelectedRows?.contains(indexPath) ?? false {
                tableView.deselectRow(at: indexPath, animated: false)
            } else if let cell = tableView.cellForRow(at: indexPath) as? SelectableCell {
                cell.showSelectionBackground(true)
                tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
            }
            handleEditingBar()
            updateTitle()
            return true
        }
        return false
    }

    func handleEditingBar() {
        if let indexPaths = tableView.indexPathsForSelectedRows,
           !indexPaths.isEmpty {
            editingBar.isEnabled = true
            evaluateMoreButton()
        } else {
            editingBar.isEnabled = false
        }

    }

    private func canResend() -> Bool {
        if dcChat.canSend, let rows = tableView.indexPathsForSelectedRows {
            let msgIds = rows.compactMap { messageIds[$0.row] }
            for msgId in msgIds {
                if !dcContext.getMessage(id: msgId).isFromCurrentSender {
                    return false
                }
            }
            return true
        } else {
            return false
        }
    }

    private func canShare() -> Bool {
        if tableView.indexPathsForSelectedRows?.count == 1,
           let rows = tableView.indexPathsForSelectedRows {
            let msgIds = rows.compactMap { messageIds[$0.row] }
            if let msgId = msgIds.first {
                let msg = dcContext.getMessage(id: msgId)
                return msg.file != nil
            }
        }
        return false
    }

    private func evaluateMoreButton() {
        editingBar.moreButton.isEnabled = canShare() || canResend()
    }

    func setEditing(isEditing: Bool, selectedAtIndexPath: IndexPath? = nil) {
        self.tableView.setEditing(isEditing, animated: true)
        self.draft.isEditing = isEditing
        self.configureDraftArea(draft: self.draft)
        if let indexPath = selectedAtIndexPath {
            _ = handleSelection(indexPath: indexPath)
        }
        self.updateTitle()
        shouldBecomeFirstResponder = isEditing
        becomeFirstResponder()
    }

    private func setDefaultBackgroundImage(view: UIImageView) {
        if #available(iOS 12.0, *) {
            view.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
        } else {
            view.image = UIImage(named: "background_light")
        }
    }

    private func copyToClipboard(ids: [Int]) {
        var stringsToCopy = ""
        if ids.count > 1 {
            let sortedIds = ids.sorted()
            var lastSenderId: Int = -1
            for id in sortedIds {
                let msg = self.dcContext.getMessage(id: id)
                var textToCopy: String?
                if msg.type == DC_MSG_TEXT || msg.type == DC_MSG_VIDEOCHAT_INVITATION, let msgText = msg.text {
                    textToCopy = msgText
                } else if let msgSummary = msg.summary(chars: 10000000) {
                    textToCopy = msgSummary
                }

                if let textToCopy = textToCopy {
                    if lastSenderId != msg.fromContactId {
                        let lastSender = msg.getSenderName(dcContext.getContact(id: msg.fromContactId))
                        stringsToCopy.append("\(lastSender):\n")
                        lastSenderId = msg.fromContactId
                    }
                    stringsToCopy.append("\(textToCopy)\n\n")
                }
            }

            if stringsToCopy.hasSuffix("\n\n") {
                stringsToCopy.removeLast(2)
            }
        } else {
            let msg = self.dcContext.getMessage(id: ids[0])
            if msg.type == DC_MSG_TEXT || msg.type == DC_MSG_VIDEOCHAT_INVITATION, let msgText = msg.text {
                stringsToCopy.append("\(msgText)")
            } else if let msgSummary = msg.summary(chars: 10000000) {
                stringsToCopy.append("\(msgSummary)")
            }
        }
        UIPasteboard.general.string = stringsToCopy
    }
}

// MARK: - BaseMessageCellDelegate
extension ChatViewController: BaseMessageCellDelegate {

    @objc func actionButtonTapped(indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        let msg = dcContext.getMessage(id: messageIds[indexPath.row])
        if msg.downloadState != DC_DOWNLOAD_DONE {
            dcContext.downloadFullMessage(id: msg.id)
        } else if msg.type == DC_MSG_WEBXDC {
            showWebxdcViewFor(message: msg)
        } else {
            let fullMessageViewController = FullMessageViewController(dcContext: dcContext, messageId: msg.id, isHalfBlocked: dcChat.isHalfBlocked)
            navigationController?.pushViewController(fullMessageViewController, animated: true)
        }
    }

    @objc func quoteTapped(indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }
        _ = handleUIMenu()
        let msg = dcContext.getMessage(id: messageIds[indexPath.row])
        if let quoteMsg = msg.quoteMessage {
            if self.chatId == quoteMsg.chatId {
                scrollToMessage(msgId: quoteMsg.id)
            } else {
                showChat(chatId: quoteMsg.chatId, messageId: quoteMsg.id, animated: false)
            }
        }
    }

    @objc func textTapped(indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }

        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        if message.isSetupMessage {
            didTapAsm(msg: message, orgText: "")
        } else if message.type == DC_MSG_VCARD {
            didTapVcard(msg: message)
        }
    }

    @objc func phoneNumberTapped(number: String, indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        let sanitizedNumber = number.filter("0123456789".contains)
        if let phoneURL = URL(string: "tel://\(sanitizedNumber)") {
            UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
        }
    }

    @objc func commandTapped(command: String, indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        if let text = messageInputBar.inputTextView.text, !text.isEmpty {
            return
        }
        messageInputBar.inputTextView.text = command + " "
    }

    @objc func urlTapped(url: URL, indexPath: IndexPath) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        if Utils.isEmail(url: url) {
            let email = Utils.getEmailFrom(url)
            self.askToChatWith(email: email)
        } else {
            UIApplication.shared.open(url)
        }
    }

    @objc func imageTapped(indexPath: IndexPath, previewError: Bool) {
        if handleUIMenu() || handleSelection(indexPath: indexPath) {
            return
        }
        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        if message.type == DC_MSG_WEBXDC {
            showWebxdcViewFor(message: message)
        } else if message.type != DC_MSG_STICKER {
            // prefer previewError over QLPreviewController.canPreview().
            // (the latter returns `true` for .webm - which is not wrong as _something_ is shown, even if the video cannot be played)
            if previewError && message.type == DC_MSG_VIDEO {
                let alert = UIAlertController(title: "To play this video, share to apps as VLC on the following page.", message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("perm_continue"), style: .default, handler: { _ in
                    self.showMediaGalleryFor(message: message)
                }))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
            } else {
                showMediaGalleryFor(message: message)
            }
        }
    }

    @objc func avatarTapped(indexPath: IndexPath) {
        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: message.fromContactId)
        navigationController?.pushViewController(contactDetailController, animated: true)
    }

    @objc func reactionsTapped(indexPath: IndexPath) {
        guard let reactions = dcContext.getMessageReactions(messageId: messageIds[indexPath.row]) else { return }

        let reactionsOverview = ReactionsOverviewViewController(reactions: reactions, context: dcContext)
        let navigationController = UINavigationController(rootViewController: reactionsOverview)
        if #available(iOS 15.0, *) {
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.preferredCornerRadius = 20
            }
        }

        self.present(navigationController, animated: true)
    }
}

// MARK: - MediaPickerDelegate
extension ChatViewController: MediaPickerDelegate {
    func onVideoSelected(url: NSURL) {
        stageVideo(url: url)
    }

    func onImageSelected(url: NSURL) {
        stageImage(url: url)
    }

    func onImageSelected(image: UIImage) {
        stageImage(image)
    }

    func onVoiceMessageRecorded(url: NSURL) {
        sendVoiceMessage(url: url)
    }

    func onVoiceMessageRecorderClosed() {
        if UIAccessibility.isVoiceOverRunning {
            _ = try? AVAudioSession.sharedInstance().setCategory(.playback)
            UIAccessibility.post(notification: .announcement, argument: nil)
        }
    }

    func onDocumentSelected(url: NSURL) {
        stageDocument(url: url)
    }

}

// MARK: - MessageInputBarDelegate
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        keepKeyboard = true
        let trimmedText = text.replacingOccurrences(of: "\u{FFFC}", with: "", options: .literal, range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let filePath = draft.attachment, let viewType = draft.viewType {
            switch viewType {
            case DC_MSG_GIF, DC_MSG_IMAGE, DC_MSG_FILE, DC_MSG_VIDEO, DC_MSG_WEBXDC, DC_MSG_VCARD:
                self.sendAttachmentMessage(viewType: viewType, filePath: filePath, message: trimmedText, quoteMessage: draft.quoteMessage)
            default:
                logger.warning("Unsupported viewType for drafted messages.")
            }
        } else if inputBar.inputTextView.images.isEmpty {
            self.sendTextMessage(text: trimmedText, quoteMessage: draft.quoteMessage)
        } else {
            // only 1 attachment allowed for now, thus it takes the first one
            self.sendImage(inputBar.inputTextView.images[0], message: trimmedText)
        }
        inputBar.inputTextView.text = String()
        inputBar.inputTextView.attributedText = nil
        draft.clear()
        draftArea.cancel()
    }

    func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        draft.text = text
        evaluateInputBar(draft: draft)
    }
}

// MARK: - DraftPreviewDelegate
extension ChatViewController: DraftPreviewDelegate {
    func onCancelQuote() {
        keepKeyboard = true
        draft.setQuote(quotedMsg: nil)
        configureDraftArea(draft: draft)
        focusInputTextView()
    }

    func onCancelAttachment() {
        keepKeyboard = true
        draft.clearAttachment()
        configureDraftArea(draft: draft)
        evaluateInputBar(draft: draft)
        focusInputTextView()
    }

    func onAttachmentAdded() {
        evaluateInputBar(draft: draft)
    }

    func onAttachmentTapped() {
        if let attachmentPath = draft.attachment {
            let attachmentURL = URL(fileURLWithPath: attachmentPath, isDirectory: false)
            if draft.viewType == DC_MSG_WEBXDC, let draftMessage = draft.draftMsg {
                showWebxdcViewFor(message: draftMessage)
            } else {
                let previewController = PreviewController(dcContext: dcContext, type: .single(attachmentURL))
                if #available(iOS 13.0, *), draft.viewType == DC_MSG_IMAGE || draft.viewType == DC_MSG_VIDEO {
                    previewController.setEditing(true, animated: true)
                    previewController.delegate = self
                }
                navigationController?.pushViewController(previewController, animated: true)
            }
        }
    }
}

// MARK: - ChatEditingDelegate
extension ChatViewController: ChatEditingDelegate {
    func onDeletePressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let messageIdsToDelete = rows.compactMap { messageIds[$0.row] }
            askToDeleteMessages(ids: messageIdsToDelete)
        }
    }

    func onMorePressed() {
        showMoreMenu()
    }

    func onForwardPressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let messageIdsToForward = rows.compactMap { messageIds[$0.row] }
            RelayHelper.shared.setForwardMessages(messageIds: messageIdsToForward)
            self.navigationController?.popViewController(animated: true)
        }
    }

    @objc func onCancelPressed() {
        setEditing(isEditing: false)
    }

    func onCopyPressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let ids = rows.compactMap { messageIds[$0.row] }
            copyToClipboard(ids: ids)
            setEditing(isEditing: false)
        }
    }
}

// MARK: - ChatSearchDelegate
extension ChatViewController: ChatSearchDelegate {
    func onSearchPreviousPressed() {
        if searchResultIndex == 0 && !searchMessageIds.isEmpty {
            searchResultIndex = searchMessageIds.count - 1
        } else {
            searchResultIndex -= 1
        }
        scrollToMessage(msgId: searchMessageIds[searchResultIndex], animated: true, scrollToText: true)
        searchAccessoryBar.updateSearchResult(sum: self.searchMessageIds.count, position: searchResultIndex + 1)
        self.reloadData()
    }

    func onSearchNextPressed() {
        if searchResultIndex == searchMessageIds.count - 1 {
            searchResultIndex = 0
        } else {
            searchResultIndex += 1
        }
        scrollToMessage(msgId: searchMessageIds[searchResultIndex], animated: true, scrollToText: true)
        searchAccessoryBar.updateSearchResult(sum: self.searchMessageIds.count, position: searchResultIndex + 1)
        self.reloadData()
    }
}

// MARK: UISearchResultUpdating
extension ChatViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
            let searchText = searchController.searchBar.text ?? ""
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                guard let self else { return }
                let resultIds = self.dcContext.searchMessages(chatId: self.chatId, searchText: searchText)
                DispatchQueue.main.async { [weak self] in

                guard let self else { return }
                    self.searchMessageIds = resultIds
                    self.searchResultIndex = self.searchMessageIds.isEmpty ? 0 : self.searchMessageIds.count - 1
                    self.searchAccessoryBar.isEnabled = !resultIds.isEmpty
                    self.searchAccessoryBar.updateSearchResult(sum: self.searchMessageIds.count, position: self.searchResultIndex + 1)

                    if let lastId = resultIds.last {
                        self.scrollToMessage(msgId: lastId, animated: true, scrollToText: true)
                    }
                    self.reloadData()
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension ChatViewController: UISearchBarDelegate {

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        configureDraftArea(draft: draft)
        return true
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        configureDraftArea(draft: draft)
        becomeFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchController.isActive = false
        configureDraftArea(draft: draft)
        becomeFirstResponder()
        navigationItem.searchController = nil
        reloadData()
    }
}

// MARK: - UISearchControllerDelegate
extension ChatViewController: UISearchControllerDelegate {
    func didPresentSearchController(_ searchController: UISearchController) {
        DispatchQueue.main.async { [weak self] in
            self?.searchController.searchBar.becomeFirstResponder()
        }
    }
}

// MARK: - ChatContactRequestBar
extension ChatViewController: ChatContactRequestDelegate {
    func onAcceptRequest() {
        dcContext.acceptChat(chatId: chatId)
        let chat = dcContext.getChat(chatId: chatId)
        if chat.isMailinglist {
            messageInputBar.isHidden = true
        } else {
            configureUIForWriting()
        }
    }

    func onBlockRequest() {
        dcContext.blockChat(chatId: chatId)
        self.navigationController?.popViewController(animated: true)
    }
    
    func onDeleteRequest() {
        self.askToDeleteChat()
    }

    func onShowInfoDialog() {
        showProtectionBrokenDialog()
    }
}


// MARK: - QLPreviewControllerDelegate
extension ChatViewController: QLPreviewControllerDelegate {
    @available(iOS 13.0, *)
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        return .updateContents
    }

    func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.draftArea.reload(draft: self.draft)
        }
    }
}

// MARK: - AudioControllerDelegate
extension ChatViewController: AudioControllerDelegate {
    func onAudioPlayFailed() {
        let alert = UIAlertController(title: String.localized("error"),
                                      message: String.localized("cannot_play_audio_file"),
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK: - UITextViewDelegate
extension ChatViewController: UITextViewDelegate {
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        if keepKeyboard {
            self.messageInputBar.inputTextView.becomeFirstResponder()
            keepKeyboard = false
            return false
        }
        return true
    }
}

// MARK: - ChatInputTextViewPasteDelegate
extension ChatViewController: ChatInputTextViewPasteDelegate {
    func onImagePasted(image: UIImage) {
        let isSticker = image.size.equalTo(CGSize(width: 140, height: 140))

        if isSticker {
            sendSticker(image)
        } else {
            stageImage(image)
        }
    }
}


extension ChatViewController: WebxdcSelectorDelegate {
    func onWebxdcFromFilesSelected(url: NSURL) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.becomeFirstResponder()
            self.onDocumentSelected(url: url)
        }
    }

    func onWebxdcSelected(msgId: Int) {
        keepKeyboard = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let message = self.dcContext.getMessage(id: msgId)
            if let filename = message.fileURL {
                let nsdata = NSData(contentsOf: filename)
                guard let data = nsdata as? Data else { return }
                let url = FileHelper.saveData(data: data, suffix: "xdc", directory: .cachesDirectory)
                self.draft.setAttachment(viewType: DC_MSG_WEBXDC, path: url)
                self.configureDraftArea(draft: self.draft)
                self.focusInputTextView()
            }
        }
    }
}

// MARK: - ChatDropInteractionDelegate
extension ChatViewController: ChatDropInteractionDelegate {
    func onImageDragAndDropped(image: UIImage) {
        stageImage(image)
    }

    func onVideoDragAndDropped(url: NSURL) {
        stageVideo(url: url)
    }

    func onFileDragAndDropped(url: NSURL) {
        stageDocument(url: url)
    }

    func onTextDragAndDropped(text: String) {
        if messageInputBar.inputTextView.text.isEmpty {
            messageInputBar.inputTextView.text = text
        } else {
            var updatedText = messageInputBar.inputTextView.text
            updatedText?.append(" \(text) ")
            messageInputBar.inputTextView.text = updatedText
        }
    }
}

// MARK: - SendContactViewControllerDelegate

extension ChatViewController: SendContactViewControllerDelegate {
    func contactSelected(_ viewController: SendContactViewController, contactId: Int) {
        guard let vcardData = dcContext.makeVCard(contactIds: [contactId]),
              let fileName = FileHelper.saveData(data: vcardData,
                                                 name: UUID().uuidString,
                                                 suffix: "vcf",
                                                 directory: .cachesDirectory),
              let vcardURL = URL(string: fileName)
        else { return }

        stageVCard(url: vcardURL)
    }
}
