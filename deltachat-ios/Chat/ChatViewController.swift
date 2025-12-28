import MapKit
import MCEmojiPicker
import QuickLook
import UIKit
import AVFoundation
import DcCore
import SDWebImage
import Combine
import CallKit

class ChatViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITableViewDropDelegate {
    public let chatId: Int

    private var dcContext: DcContext
    private var messageIds: [Int] = []
    private var isVisibleToUser: Bool = false
    private var reactionMessageId: Int?
    private var contextMenuVisible = false

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

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundView = backgroundContainer
        tableView.register(TextMessageCell.self, forCellReuseIdentifier: TextMessageCell.reuseIdentifier)
        tableView.register(ImageTextCell.self, forCellReuseIdentifier: ImageTextCell.reuseIdentifier)
        tableView.register(FileTextCell.self, forCellReuseIdentifier: FileTextCell.reuseIdentifier)
        tableView.register(InfoMessageCell.self, forCellReuseIdentifier: InfoMessageCell.reuseIdentifier)
        tableView.register(AudioMessageCell.self, forCellReuseIdentifier: AudioMessageCell.reuseIdentifier)
        tableView.register(WebxdcCell.self, forCellReuseIdentifier: WebxdcCell.reuseIdentifier)
        tableView.register(ContactCardCell.self, forCellReuseIdentifier: ContactCardCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.allowsMultipleSelectionDuringEditing = true

        // Transform the tableView to maintain scroll position from bottom when views are added
        // this flips the default behavior of maintaining scroll position from the top of the
        // scrollview when views are added to maintaining scroll position from the bottom
        tableView.transform = CGAffineTransform(scaleX: 1, y: -1)

        // Since the view is flipped, its safeArea will be flipped, luckily we can ignore it
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.automaticallyAdjustsScrollIndicatorInsets = false
        tableView.publisher(for: \.contentInset)
            .assign(to: \.verticalScrollIndicatorInsets, on: tableView)
            .store(in: &bag)

        return tableView
    }()

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
        view.transform = CGAffineTransform(scaleX: 1, y: -1)
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

    private lazy var navBarTap: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(chatProfilePressed))
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(onCancelPressed))
    }()
    
    /// When a context menu preview is created through `tableView(_:previewForHighlightingContextMenuWithConfiguration:)`
    /// it is stored here so we can hide it when a user scrolls as the system does not hide
    /// snapshots right away probably assuming it is part of the view hierarchy.
    private weak var lastContextMenuPreviewSnapshot: UIView?

    private let titleView = ChatTitleView()

    private lazy var dcChat: DcChat = {
        return dcContext.getChat(chatId: chatId)
    }()

    private var customInputAccessoryView: UIView? {
        didSet { reloadInputViews() }
    }
    override var inputAccessoryView: UIView? {
        get { customInputAccessoryView }
        set { customInputAccessoryView = newValue }
    }

    override var canBecomeFirstResponder: Bool {
        if let p = presentedViewController, !p.isBeingDismissed, !(p is UISearchController) {
            // Don't show inputAccessoryView when anything other than searchController is presented
            return false
        } else if navigationController?.topViewController != self {
            // Don't show inputAccessoryView when not top view controller
            return false
        } else if contextMenuVisible {
            // Don't show inputAccessoryView when context menu is visible
            return false
        } else {
            return dcChat.canSend || dcChat.isContactRequest || tableView.isEditing || presentedViewController is UISearchController
        }
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

    private var _bag: [Any/*Cancellable*/] = []
    private var bag: [AnyCancellable] {
        get { _bag.compactMap { $0 as? AnyCancellable } }
        set { _bag = newValue }
    }

    init(dcContext: DcContext, chatId: Int, highlightedMsg: Int? = nil) {
        self.dcContext = dcContext
        self.chatId = chatId
        self.highlightedMsg = highlightedMsg
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleIncomingMessage(_:)), name: Event.incomingMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleMessagesChanged(_:)), name: Event.messagesChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleMsgReadDeliveredReactionFailed(_:)), name: Event.messageReadDeliveredFailedReaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleChatModified(_:)), name: Event.chatModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleContactsChanged(_:)), name: Event.contactsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.handleEphemeralTimerModified(_:)), name: Event.ephemeralTimerModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.fillSuperview()

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance

        navigationItem.backButtonTitle = String.localized("chat")
        definesPresentationContext = true

        // Binding to the tableView will enable interactive dismissal
        keyboardManager?.bind(to: tableView)
        keyboardManager?.on(event: .willShow) { [tableView] notification in
            // Using superview instead of window here because in iOS 13+ a modal can change
            // the frame of the vc it is presented over which causes this calculation to be off.
            let globalTableViewFrame = tableView.convert(tableView.bounds, to: tableView.superview)
            let intersection = globalTableViewFrame.intersection(notification.endFrame)
            let inset = max(intersection.height, tableView.safeAreaInsets.bottom)
            // willShow is sometimes called when the keyboard is being hidden or when the kb was
            // already shown due to interactive dismissal getting canceled.
            guard tableView.contentInset.top != inset else { return }
            UIView.animate(withDuration: notification.timeInterval, delay: 0, options: notification.animationOptions) {
                tableView.contentInset.top = inset
                if tableView.contentOffset.y < 30 {
                    // If user is less than 30 away from the bottom, we scroll
                    // the bottom of the content to the top of the keyboard.
                    tableView.contentOffset.y -= inset + tableView.contentOffset.y
                }
            }
        }

        if !dcContext.isConfigured() {
            // TODO: display message about nothing being configured
            return
        }
        configureEmptyStateView()

        if dcChat.canSend {
            configureUIForWriting()
        } else if dcChat.isContactRequest {
            configureContactRequestBar()
        } else {
            messageInputBar.isHidden = true
        }
        loadMessages()
    }

    private func configureUIForWriting() {
        configureMessageInputBar()
        draft.parse(draftMsg: dcContext.getDraft(chatId: chatId))
        messageInputBar.inputTextView.text = draft.text
        configureDraftArea(draft: draft, animated: false)
        tableView.dragInteractionEnabled = true
        tableView.dropDelegate = self
        tableView.dragDelegate = self
    }

    public func activateSearchOnAppear() {
        activateSearch = true
        navigationItem.searchController = self.searchController
    }

    private func configureEmptyStateView() {
        emptyStateView.addCenteredTo(parentView: backgroundContainer, evadeKeyboard: true)
    }

    var isInitialViewWillAppear = true
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
        
        switch RelayHelper.shared.data {
        case .forwardMessages:
            resignFirstResponder()
            askToForwardMessage()
        case .forwardVCard(let vcardData):
            if let vcardURL = prepareVCardData(vcardData) {
                stageVCard(url: vcardURL)
                RelayHelper.shared.finishRelaying()
            }
        case let .forwardMessage(text, fileData, fileName):
            if let text {
                messageInputBar.inputTextView.text = text
            }
            if let fileData, let file = FileHelper.saveData(data: fileData, name: fileName, directory: .cachesDirectory) {
                stageDocument(url: NSURL(fileURLWithPath: file))
            }
            RelayHelper.shared.finishRelaying()
        case .mailto(_, draft: let draft):
            messageInputBar.inputTextView.text = draft
            RelayHelper.shared.finishRelaying()
        case .share(let items):
            let description = Dictionary(items.map { ($0.type, 1) }, uniquingKeysWith: +)
                .compactMap { viewType, count in
                    switch viewType { // TODO: Localize
                    case DC_MSG_GIF: "\(count) GIF(s)"
                    case DC_MSG_IMAGE: "\(count) image(s)"
                    case DC_MSG_VIDEO: "\(count) video(s)"
                    case DC_MSG_FILE: "\(count) file(s)"
                    case DC_MSG_TEXT: "\(count) text message(s)"
                    default: nil
                    }
                }
                .joined(separator: ", ")
            askToShareMessage(description: description)
        case .none: break
        }

        messageInputBar.scrollDownButton.isHidden = true

        if isInitialViewWillAppear {
            becomeFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.tableView.contentInset.top = max(self.inputAccessoryView?.frame.height ?? 0, self.tableView.safeAreaInsets.bottom)
                if let msgId = self.highlightedMsg, self.messageIds.firstIndex(of: msgId) != nil {
                    self.scrollToMessage(msgId: msgId, animated: false)
                    self.highlightedMsg = nil
                } else {
                    self.scrollToLastUnseenMessage(animated: false)
                }
            }
        }
        isInitialViewWillAppear = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppStateRestorer.shared.storeLastActiveChat(chatId: chatId)
        reloadInputViews()
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
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        AppStateRestorer.shared.resetLastActiveChat()
        handleUserVisibility(isVisible: false)
        audioController.stopAnyOngoingPlaying()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // Manually set the safe area because tableView is flipped
        tableView.contentInset.bottom = tableView.safeAreaInsets.top
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            // going back to previous screen
            draft.save(context: dcContext)
        }
    }

    // MARK: - Notifications

    @objc private func handleEphemeralTimerModified(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateTitle()
        }
    }

    @objc private func handleChatModified(_ notification: Notification) {
        guard let ui = notification.userInfo, chatId == ui["chat_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            dcChat = self.dcContext.getChat(chatId: chatId)
            updateTitle()
            checkInputBarVisibility()
        }
    }

    @objc private func handleContactsChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            dcChat = self.dcContext.getChat(chatId: chatId)
            refreshMessages()
            updateTitle()
            checkInputBarVisibility()
        }
    }

    private func checkInputBarVisibility() {
        if dcChat.canSend {
            if messageInputBar.isHidden {
                configureUIForWriting()
                messageInputBar.isHidden = false
                becomeFirstResponder()
            }
        } else if !dcChat.isContactRequest {
            if !messageInputBar.isHidden {
                messageInputBar.isHidden = true
            }
        }
    }

    @objc private func handleMessagesChanged(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        let chatId = ui["chat_id"] as? Int ?? 0

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if chatId == 0 || chatId == self.chatId {
                let messageId = ui["message_id"] as? Int ?? 0
                if messageId > 0 {
                    let msg = self.dcContext.getMessage(id: messageId)
                    if msg.state == DC_STATE_OUT_DRAFT && msg.type == DC_MSG_WEBXDC {
                        self.draft.draftMsg = msg
                        self.configureDraftArea(draft: draft, animated: false)
                        return
                    }
                }

                self.refreshMessages()
                self.updateTitle()
                self.updateScrollDownButtonVisibility()
                self.markSeenMessagesInVisibleArea()
            }
        }
    }

    @objc private func handleMsgReadDeliveredReactionFailed(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }

        let chatId = ui["chat_id"] as? Int ?? 0
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if chatId == 0 || chatId == self.chatId {
                let messageId = ui["message_id"] as? Int ?? 0
                if messageId > 0 {
                    let msg = self.dcContext.getMessage(id: messageId)
                    if msg.state == DC_STATE_OUT_DRAFT && msg.type == DC_MSG_WEBXDC {
                        self.draft.draftMsg = msg
                        self.configureDraftArea(draft: draft, animated: false)
                        return
                    }
                }

                self.refreshMessages()
                self.updateTitle()
                self.markSeenMessagesInVisibleArea()
            }
        }
    }

    @objc private func handleIncomingMessage(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let chatId = ui["chat_id"] as? Int ?? 0
            if chatId == 0 || chatId == self.chatId {
                self.refreshMessages()
                self.updateTitle()
                self.updateScrollDownButtonVisibility()
                self.markSeenMessagesInVisibleArea()
            }
        }
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            handleUserVisibility(isVisible: true)
        }
        // Update the last seen indicator
        updateTitle()
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
            markSeenMessagesInVisibleArea()
        }
    }

    /// UITableView methods
    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        func dequeueCell<T: UITableViewCell & ReusableCell>(ofType _: T.Type = T.self) -> T {
            let cell = tableView.dequeueReusableCell(withIdentifier: T.reuseIdentifier, for: indexPath)
            cell.transform = CGAffineTransform(scaleX: 1, y: -1)
            return cell as? T ?? { fatalError("WTF?! Wrong Cell, expected \(T.self)") }()
        }

        let id = messageIds[indexPath.row]
        if id == DC_MSG_ID_DAYMARKER {
            let cell = dequeueCell(ofType: InfoMessageCell.self)
            if indexPath.row - 1 >= 0 {
                var nextMessageId = messageIds[indexPath.row - 1]
                if nextMessageId == DC_MSG_ID_MARKER1 && indexPath.row - 2 >= 0 {
                    nextMessageId = messageIds[indexPath.row - 2]
                }
                let nextMessage = dcContext.getMessage(id: nextMessageId)
                let dateString = DateUtils.getDateString(date: nextMessage.sentDate, relativeToCurrentDate: true)
                cell.update(text: dateString, weight: .bold, isHeader: true)
            } else {
                cell.update(text: "ErrDaymarker")
            }
            return cell
        } else if id == DC_MSG_ID_MARKER1 {
            // unread messages marker
            let cell = dequeueCell(ofType: InfoMessageCell.self)
            let freshMsgsCount = indexPath.row
            cell.update(text: String.localized(stringID: "chat_n_new_messages", parameter: freshMsgsCount))
            return cell
        }

        let message = dcContext.getMessage(id: id)
        if message.isInfo {
            let cell = dequeueCell(ofType: InfoMessageCell.self)
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
        case DC_MSG_IMAGE, DC_MSG_GIF, DC_MSG_VIDEO, DC_MSG_STICKER:
            cell = dequeueCell(ofType: ImageTextCell.self)

        case DC_MSG_FILE:
            cell = dequeueCell(ofType: FileTextCell.self)

        case DC_MSG_WEBXDC:
            cell = dequeueCell(ofType: WebxdcCell.self)
        case DC_MSG_AUDIO, DC_MSG_VOICE:
            if message.isUnsupportedMediaFile {
                cell = dequeueCell(ofType: FileTextCell.self)
            } else {
                let audioMessageCell = dequeueCell(ofType: AudioMessageCell.self)
                audioController.update(audioMessageCell, with: message.id)
                cell = audioMessageCell
            }
        case DC_MSG_VCARD:
            cell = dequeueCell(ofType: ContactCardCell.self)
        default:
            cell = dequeueCell(ofType: TextMessageCell.self)
        }

        let showAvatar: Bool
        let showName: Bool
        if message.overrideSenderName != nil || dcChat.isSelfTalk {
            showAvatar = !message.isFromCurrentSender
            showName = true
        } else {
            showAvatar = dcChat.isMultiUser && !message.isFromCurrentSender
            showName = dcChat.isMultiUser
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

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastContextMenuPreviewSnapshot?.removeFromSuperview()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            markSeenMessagesInVisibleArea()
            updateScrollDownButtonVisibility()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        markSeenMessagesInVisibleArea()
        updateScrollDownButtonVisibility()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        markSeenMessagesInVisibleArea()
        updateScrollDownButtonVisibility()
    }

    private func updateScrollDownButtonVisibility() {
        messageInputBar.scrollDownButton.isHidden = contextMenuVisible || messageIds.isEmpty || isLastMessageVisible()
    }

    private func configureContactRequestBar() {
        messageInputBar.separatorLine.backgroundColor = DcColors.colorDisabled

        let bar = ChatContactRequestBar(dcChat.isMultiUser && !dcChat.isMailinglist ? .delete : .block, infoText: nil)
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        messageInputBar.setMiddleContentView(bar, animated: false)

        messageInputBar.setLeftStackViewWidthConstant(to: 0, animated: false)
        messageInputBar.setRightStackViewWidthConstant(to: 0, animated: false)
        messageInputBar.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        messageInputBar.setStackViewItems([], forStack: .top, animated: false)
        messageInputBar.onScrollDownButtonPressed = { [weak self] in
            self?.scrollToBottom()
        }
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
            messageInputBar.inputTextView.resignFirstResponder()
        } else {
            messageInputBar.setMiddleContentView(messageInputBar.inputTextView, animated: false)
            messageInputBar.setLeftStackViewWidthConstant(to: draft.sendEditRequestFor == nil ? 40 : 0, animated: false)
            messageInputBar.setRightStackViewWidthConstant(to: 40, animated: false)
            messageInputBar.padding = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 12)
            inputAccessoryView = messageInputBar
        }

        messageInputBar.setStackViewItems([draftArea], forStack: .top, animated: animated)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(actions: [])
    }


    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)
        if !canReply(to: message) {
            return nil
        }

        let action = UIContextualAction(style: .normal, title: nil) { [weak self] (_, _, completionHandler) in
            self?.replyToMessage(messageId)
            completionHandler(true)
        }

        action.image = UIImage(systemName: "arrowshape.turn.up.left.fill")?
            .sd_tintedImage(with: DcColors.defaultInverseColor)?
            .sd_flippedImage(withHorizontal: false, vertical: true)

        action.backgroundColor = .systemGray.withAlphaComponent(0.0) // nil or .clear do not result in transparence
        action.accessibilityLabel = String.localized("notify_reply_button")
        let configuration = UISwipeActionsConfiguration(actions: [action])

        return configuration
    }

    func replyToMessage(_ msgId: Int) {
        let message = dcContext.getMessage(id: msgId)
        self.draft.setQuote(quotedMsg: message)
        self.configureDraftArea(draft: self.draft)
        focusInputTextView()
    }

    func replyPrivatelyToMessage(_ msgId: Int) {
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

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return tableView.cellForRow(at: indexPath) is SelectableCell
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let tableViewCell = tableView.cellForRow(at: indexPath)
        if let selectableCell = tableViewCell as? SelectableCell,
           !(tableView.isEditing &&
             tableViewCell is InfoMessageCell &&
             messageIds[indexPath.row] <= DC_MSG_ID_LAST_SPECIAL) {
            selectableCell.showSelectionBackground(tableView.isEditing)
            return indexPath
        }
        return nil
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            handleEditingBar()
            updateTitle()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            handleEditingBar()
            updateTitle()
            return
        }
        // handle taps outside textTapped(), imageTapped(), avatarTapped(), statusTapped() etc.
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)
        switch (message.type, message.infoType) {
        case (DC_MSG_FILE, _), (DC_MSG_AUDIO, _), (DC_MSG_VOICE, _):
            showMediaGalleryFor(message: message)
        case (DC_MSG_VCARD, _):
            didTapVcard(msg: message)
        case (DC_MSG_WEBXDC, _):
            showWebxdcViewFor(message: message)
        case (DC_MSG_CALL, _):
            CallManager.shared.answerIncomingCall(forMessage: messageId, chatId: chatId, contextId: dcContext.id)
        case (_, DC_INFO_WEBXDC_INFO_MESSAGE):
            if let parent = message.parent {
                showWebxdcViewFor(message: parent, href: message.getWebxdcHref())
            }
        case (_, DC_INFO_PROTECTION_ENABLED), (_, DC_INFO_CHAT_E2EE):
            showProtectionEnabledDialog()
        case (_, DC_INFO_INVALID_UNENCRYPTED_MAIL):
            showInvalidUnencryptedDialog()
        default:
            if let contactId = message.infoContactId, contactId != DC_CONTACT_ID_SELF {
                navigationController?.pushViewController(ProfileViewController(dcContext, contactId: contactId), animated: true)
            }
        }
    }

    func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        let canMultiSelect = !searchController.isActive
        return canMultiSelect
    }
    func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        setEditing(isEditing: true)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        messageInputBar.inputTextView.layer.borderColor = DcColors.colorDisabled.cgColor
        if UserDefaults.standard.string(forKey: Constants.Keys.backgroundImageName) == nil {
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

        var dcContact: DcContact?
        if tableView.isEditing {
            navigationItem.titleView = nil
            let cnt = tableView.indexPathsForSelectedRows?.count ?? 0
            navigationItem.title = String.localized(stringID: "n_selected", parameter: cnt)
            self.navigationItem.setLeftBarButton(cancelButton, animated: true)
            navigationItem.rightBarButtonItems = nil
        } else {
            let subtitle: String?
            let chatContactIds = dcChat.getContactIds(dcContext)
            if dcChat.isMailinglist {
                subtitle = String.localized("mailing_list")
            } else if dcChat.isInBroadcast {
                subtitle = String.localized(stringID: "channel")
            } else if dcChat.isOutBroadcast {
                subtitle = String.localized(stringID: "n_recipients", parameter: chatContactIds.count)
            } else if dcChat.isMultiUser {
                if chatContactIds.count > 1 || chatContactIds.contains(Int(DC_CONTACT_ID_SELF)) {
                    subtitle = String.localized(stringID: "n_members", parameter: chatContactIds.count)
                } else {
                    // do not show misleading "1 member" in case securejoin has not finished
                    subtitle = "…"
                }
            } else if dcChat.isDeviceTalk {
                subtitle = String.localized("device_talk_subtitle")
            } else if dcChat.isSelfTalk {
                subtitle = String.localized("chat_self_talk_subtitle")
            } else if chatContactIds.count >= 1 {
                dcContact = dcContext.getContact(id: chatContactIds[0])
                if let dcContact, dcContact.isBot {
                    subtitle = String.localized("bot")
                } else {
                    subtitle = nil
                }
            } else {
                subtitle = nil
            }

            titleView.updateTitleView(title: dcChat.name, subtitle: subtitle, isMuted: dcChat.isMuted,
                                      isEphemeral: dcContext.getChatEphemeralTimer(chatId: dcChat.id) > 0, isSendingLocations: dcChat.isSendingLocations)
            titleView.layoutIfNeeded()
            navigationItem.titleView = titleView
            self.navigationItem.setLeftBarButton(nil, animated: true)
            
            var rightBarButtonItems = [UIBarButtonItem]()

            let button = UIBarButtonItem(image: UIImage(systemName: "square.grid.2x2"), style: .plain, target: self, action: #selector(appsAndMediaPressed))
            button.accessibilityLabel = String.localized("apps_and_media")
            rightBarButtonItems.append(button)

            if let image = dcChat.profileImage {
                titleView.initialsBadge.setImage(image)
            } else {
                titleView.initialsBadge.setName(dcChat.name)
                titleView.initialsBadge.setColor(dcChat.color)
            }

            if !dcChat.isSelfTalk {
                let recentlySeen = DcUtils.showRecentlySeen(context: dcContext, chat: dcChat)
                titleView.initialsBadge.setRecentlySeen(recentlySeen)

                if !dcChat.isMultiUser && dcChat.canSend && UserDefaults.standard.bool(forKey: "pref_calls_enabled"),
                   let dcContact, dcContact.isKeyContact {
                    let button = UIBarButtonItem(image: UIImage(systemName: "phone"), style: .plain, target: self, action: #selector(callPressed))
                    rightBarButtonItems.append(button)
                }
            } else {
                let button = UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: self, action: #selector(searchPressed))
                rightBarButtonItems.append(button)
            }
            
            navigationItem.rightBarButtonItems = rightBarButtonItems
        }
    }

    private var refreshMessagesAfterEditing = false
    private func refreshMessages() {
        guard !tableView.isEditing else {
            return refreshMessagesAfterEditing = true
        }
        messageIds = dcContext.getChatMsgs(chatId: chatId, flags: DC_GCM_ADDDAYMARKER).reversed()
        reloadData()
        showEmptyStateView(messageIds.isEmpty)
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
        var msgIds = dcContext.getChatMsgs(chatId: chatId, flags: DC_GCM_ADDDAYMARKER)
        let freshMsgsCount = self.dcContext.getUnreadMessages(chatId: self.chatId)
        if freshMsgsCount > 0 && msgIds.count >= freshMsgsCount {
            let index = msgIds.count - freshMsgsCount
            msgIds.insert(Int(DC_MSG_ID_MARKER1), at: index)
        }
        self.messageIds = msgIds.reversed()
        self.showEmptyStateView(self.messageIds.isEmpty)
        self.reloadData()
    }

    private func canReply(to message: DcMsg) -> Bool {
        return !message.isMarkerOrInfo && dcChat.canSend
    }

    private func canReplyPrivately(to message: DcMsg) -> Bool {
        return !message.isMarkerOrInfo && dcChat.isMultiUser && !message.isFromCurrentSender
    }

    /// Verifies if the last message cell is fully visible
    private func isLastMessageVisible(allowPartialVisibility: Bool = true) -> Bool {
        guard !messageIds.isEmpty else { return false }
        // 1 because messageIds is reversed and last message is DC_MSG_ID_LAST_SPECIAL
        let lastIndexPath = IndexPath(item: 1, section: 0)

        var cellRect = tableView.rectForRow(at: lastIndexPath)
        cellRect.origin = tableView.convert(cellRect.origin, to: tableView.superview)

        var visibleRect = tableView.frame
        // Adjust for keyboard
        visibleRect.size.height -= tableView.contentInset.top
        // Adjust for navbar
        visibleRect.origin.y += tableView.contentInset.bottom
        visibleRect.size.height -= tableView.contentInset.bottom

        if allowPartialVisibility {
            return visibleRect.intersects(cellRect)
        } else {
            return visibleRect.contains(cellRect)
        }
    }

    private func scrollToBottom(animated: Bool = true) {
        // tableView is flipped so top is bottom
        tableView.scrollToTop(animated: animated)
    }

    private func scrollToLastUnseenMessage(animated: Bool) {
        if let markerMessageIndex = self.messageIds.firstIndex(of: Int(DC_MSG_ID_MARKER1)) {
            let indexPath = IndexPath(row: markerMessageIndex, section: 0)
            self.scrollToRow(at: indexPath, animated: animated)
        } else {
            scrollToBottom(animated: animated)
        }
    }

    /// Scroll to a message
    ///
    /// - Parameters:
    ///     - msgId: The id of the message to scroll to
    ///     - animated: Wether the scrolling should be animated
    ///     - searchString: The text to scroll to inside the message
    private func scrollToMessage(msgId: Int, animated: Bool = true, scrollToText searchString: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let index = self.messageIds.firstIndex(of: msgId) else { return }
            let indexPath = IndexPath(row: index, section: 0)

            if let searchString, !UIAccessibility.isVoiceOverRunning {
                let isVisible = self.tableView.indexPathsForVisibleRows?.contains(indexPath) == false
                UIView.animate(withDuration: !isVisible && animated ? 0.3 : 0) {
                    if isVisible {
                        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
                    }
                } completion: { [weak self] _ in
                    guard let self else { return }
                    if let messageCell = self.tableView.cellForRow(at: indexPath) as? BaseMessageCell {
                        let textOffset = messageCell.getTextOffset(of: searchString)
                        let textOrigin = messageCell.convert(
                            CGPoint(x: 0, y: textOffset),
                            to: self.tableView
                        )
                        let topInset = self.tableView.safeAreaInsets.top/2
                        var bottomInset = 12.0
                        if !self.messageInputBar.scrollDownButton.isHidden {
                            bottomInset += 12 + self.messageInputBar.scrollDownButton.bounds.height
                        }
                        let textFrame = CGRect(origin: textOrigin, size: CGSize(width: 1, height: 0))
                            .inset(by: .init(top: topInset, left: 0, bottom: bottomInset, right: 0))
                        self.tableView.scrollRectToVisible(textFrame, animated: animated)
                        messageCell.messageBackgroundContainer.blink()
                    }
                }
            } else {
                self.scrollToRow(at: indexPath, animated: animated)
            }
        }
    }

    private func scrollToRow(at indexPath: IndexPath, animated: Bool, focusWithVoiceOver: Bool = true) {
        if UIAccessibility.isVoiceOverRunning && focusWithVoiceOver {
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
            markSeenMessagesInVisibleArea()
            updateScrollDownButtonVisibility()
            forceVoiceOverFocussingCell(at: indexPath) { [weak self] in
                self?.tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
            }
        } else {
            UIView.animate(withDuration: animated ? 0.3 : 0) {
                self.tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
            } completion: { [weak self] _ in
                guard let self else { return }
                // If the cell does not fit on the screen, scroll to the top of it.
                let cell = self.tableView.cellForRow(at: indexPath)
                let cellHeight = cell?.bounds.height
                let viewHeight = self.tableView.bounds.height - self.tableView.contentInset.vertical
                if let cellHeight, cellHeight > viewHeight {
                    self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
                }
                if let cell = cell as? BaseMessageCell {
                    cell.messageBackgroundContainer.blink()
                }
            }
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
            if dcChat.isMultiUser {
                if dcChat.isOutBroadcast {
                    emptyStateView.text = String.localized("chat_new_channel_hint")
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

    private func configureMessageInputBar() {
        messageInputBar.delegate = self
        messageInputBar.inputTextView.tintColor = DcColors.primary
        messageInputBar.inputTextView.placeholder = String.localized("chat_input_placeholder")
        messageInputBar.inputTextView.accessibilityLabel = String.localized("write_message_desktop")
        messageInputBar.separatorLine.backgroundColor = DcColors.colorDisabled
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
        messageInputBar.inputTextView.imagePasteDelegate = self
        messageInputBar.onScrollDownButtonPressed = { [weak self] in
            self?.scrollToBottom()
        }
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

        let attachButton = InputBarButtonItem()
            .configure {
                $0.spacing = .fixed(0)
                let clipperIcon = UIImage(named: "ic_attach_file_36pt")?.withRenderingMode(.alwaysTemplate)
                $0.image = clipperIcon
                $0.tintColor = DcColors.primary
                $0.setSize(CGSize(width: 40, height: 40), animated: false)
                $0.accessibilityLabel = String.localized("menu_add_attachment")
                $0.accessibilityTraits = .button
            }.onSelected {
                $0.tintColor = UIColor.themeColor(light: .lightGray, dark: .darkGray)
            }.onDeselected {
                $0.tintColor = DcColors.primary
            }
        attachButton.showsMenuAsPrimaryAction = true
        attachButton.menu = UIMenu() // otherwise .menuActionTriggered is not triggered
        attachButton.addAction(UIAction { [weak attachButton, weak self] _ in
            attachButton?.menu = self?.clipperButtonMenu()
        }, for: .menuActionTriggered)

        let leftItems = [attachButton]

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
        CATransaction.flush()

        self.showChatDetail(chatId: self.chatId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.titleView.setEnabled(true) // /immedidate feedback
        }
    }

    @objc private func searchPressed() {
        navigationItem.searchController = self.searchController
        DispatchQueue.main.async { [weak self] in
            self?.searchController.isActive = true
        }
    }

    @objc private func appsAndMediaPressed() {
        navigationController?.pushViewController(AllMediaViewController(dcContext: dcContext, chatId: chatId), animated: true)
    }

    @objc private func callPressed() {
        CallManager.shared.placeOutgoingCall(dcContext: dcContext, dcChat: dcChat)
    }

    private func clipperButtonMenu() -> UIMenu {
        var actions = [UIMenuElement]()
        func action(_ localized: String, _ systemImage: String, attributes: UIMenuElement.Attributes = [], _ handler: @escaping (ChatViewController) -> Void) -> UIAction {
            UIAction(title: String.localized(localized), image: UIImage(systemName: systemImage), attributes: attributes, handler: { [unowned self] _ in handler(self) })
        }

        actions.append(UIMenu(options: [.displayInline], children: [
            action("camera", "camera", { $0.showCameraViewController() }),
            action("gallery", "photo.on.rectangle", { $0.showPhotoVideoLibrary() })
        ]))

        actions.append(action("file", "doc", { $0.showFilesLibrary() }))
        actions.append(action("webxdc_app", "square.grid.2x2", { $0.showAppPicker() }))
        actions.append(action("voice_message", "mic", { $0.showVoiceMessageRecorder() }))
        if UserDefaults.standard.bool(forKey: "location_streaming") {
            let isLocationStreaming = dcContext.isSendingLocationsToChat(chatId: chatId)
            actions.append(action(
                isLocationStreaming ? "stop_sharing_location" : "location",
                isLocationStreaming ? "location.slash" : "location",
                attributes: isLocationStreaming ? .destructive : [],
                { $0.locationStreamingButtonPressed() }
            ))
        }
        actions.append(action("contact", "person.crop.circle", { $0.showContactList() }))

        return UIMenu(children: actions)
    }

    private func confirmationAlert(title: String, message: String? = nil, actionTitle: String, actionStyle: UIAlertAction.Style = .default, actionHandler: @escaping ((UIAlertAction) -> Void), cancelHandler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: actionTitle, style: actionStyle, handler: actionHandler))

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: cancelHandler ?? { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func onMultipleSaveOrUnsave(doSave: Bool) {
        guard let rows = tableView.indexPathsForSelectedRows else { return }
        let msgIds = rows.compactMap { messageIds[$0.row] }
        setEditing(isEditing: false)
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            // unsave unconditionally, this forces re-saving and moves new saved messages to the bottom as expected
            for msgId in msgIds {
                let msg = dcContext.getMessage(id: msgId)
                if msg.savedMessageId != 0 {
                    dcContext.deleteMessage(msgId: msg.savedMessageId)
                }
            }
            // save as needed
            if doSave {
                dcContext.saveMessages(with: msgIds)
            }
        }
    }

    private func onResendActionPressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let selectedMsgIds = rows.compactMap { messageIds[$0.row] }
            dcContext.resendMessages(msgIds: selectedMsgIds)
            setEditing(isEditing: false)
        }
    }

    private func askToDeleteChat() {
        let chat = dcContext.getChat(chatId: chatId)
        let title = String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), chat.name)
        confirmationAlert(title: title, actionTitle: String.localized("delete"), actionStyle: .destructive,
                          actionHandler: { [weak self] _ in
            guard let self else { return }
            // remove message observers early to avoid careless calls to dcContext methods
            self.dcContext.deleteChat(chatId: self.chatId)
            if #available(iOS 17.0, *) {
                UserDefaults.shared?.removeChatFromHomescreenWidget(accountId: dcContext.id, chatId: chatId)
            }
            self.navigationController?.popViewController(animated: true)
        })
    }


    private func askToChatWith(email: String) {
        var contactId = self.dcContext.lookupContactIdByAddress(email)
        if contactId == 0 {
            contactId = dcContext.createContact(name: "", email: email)
        }

        if dcContext.getChatIdByContactId(contactId) != 0 {
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
        func deleteInUi(ids: [Int]) {
            if #available(iOS 17.0, *) {
                ids.forEach { UserDefaults.shared?.removeWebxdcFromHomescreen(accountId: self.dcContext.id, messageId: $0) }
            }
            if self.tableView.isEditing {
                self.setEditing(isEditing: false)
            }
        }

        var canDeleteForEveryone = true
        if dcChat.canSend && dcChat.isEncrypted && !dcChat.isSelfTalk {
            for msgId in ids {
                let msg = dcContext.getMessage(id: msgId)
                if !msg.isFromCurrentSender {
                    canDeleteForEveryone = false
                    break
                }
            }
        } else {
            canDeleteForEveryone = false
        }

        let alert = UIAlertController(title: String.localized(stringID: "ask_delete_messages", parameter: ids.count), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized(dcChat.isSelfTalk ? "delete" : "delete_for_me"), style: .destructive, handler: { [weak self] _ in
            self?.dcContext.deleteMessages(msgIds: ids)
            deleteInUi(ids: ids)
        }))
        if canDeleteForEveryone {
            alert.addAction(UIAlertAction(title: String.localized("delete_for_everyone"), style: .destructive, handler: { [weak self] _ in
                self?.dcContext.sendDeleteRequest(msgIds: ids)
                deleteInUi(ids: ids)
            }))
        }
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func askToForwardMessage() {
        let chat = dcContext.getChat(chatId: chatId)
        confirmationAlert(
            title: String.localizedStringWithFormat(String.localized("ask_forward"), chat.name),
            actionTitle: String.localized("forward"),
            actionHandler: { [weak self] _ in
                guard let self else { return }
                RelayHelper.shared.forwardIdsAndFinishRelaying(to: chatId)
                becomeFirstResponder()
            },
            cancelHandler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }
        )
    }
    
    private func askToShareMessage(description: String) {
        let chat = dcContext.getChat(chatId: chatId)
        confirmationAlert(
            title: String.localizedStringWithFormat("Share to %1$@?", chat.name), // TODO: Localise
            message: description,
            actionTitle: String.localized("menu_share"), // TODO: Confirm I should use this localized string
            actionHandler: { [weak self] _ in
                guard let self else { return }
                RelayHelper.shared.shareAndFinishRelaying(to: chatId)
                becomeFirstResponder()
            },
            cancelHandler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }
        )
    }

    // MARK: - coordinator
    private func showChatDetail(chatId: Int) {
        let chat = dcContext.getChat(chatId: chatId)
        if !chat.isMultiUser {
            if let contactId = chat.getContactIds(dcContext).first {
                navigationController?.pushViewController(ProfileViewController(dcContext, contactId: contactId), animated: true)
            }
        } else {
            navigationController?.pushViewController(ProfileViewController(dcContext, chatId: chatId), animated: true)
        }
    }

    func showChat(chatId: Int, messageId: Int? = nil, animated: Bool = true) {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.showChat(chatId: chatId, msgId: messageId, animated: animated, clearViewControllerStack: true)
        }
    }

    private func showFilesLibrary() {
        mediaPicker?.showFilesLibrary()
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

    private func showPhotoVideoLibrary() {
        mediaPicker?.showGallery()
    }

    private func showProtectionEnabledDialog() {
        let alert = UIAlertController(title: String.localized("chat_protection_enabled_explanation"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("learn_more"), style: .default, handler: { [weak self] _ in
            self?.openHelp(fragment: "#e2ee")
        }))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func showInvalidUnencryptedDialog() {
        let alert = UIAlertController(title: String.localized("invalid_unencrypted_explanation"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("learn_more"), style: .default, handler: { [weak self] _ in
            self?.openHelp(fragment: "#howtoe2ee")
        }))
        alert.addAction(UIAlertAction(title: String.localized("qrscan_title"), style: .default, handler: { _ in
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.appCoordinator.presentQrCodeController()
            }
        }))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func showAppPicker() {
        let appPicker = AppPickerViewController(context: dcContext)
        appPicker.delegate = self
        let navigationController = UINavigationController(rootViewController: appPicker)

        if #available(iOS 15.0, *), let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.large()]
        }

        present(navigationController, animated: true)
    }

    private func showContactList() {
        let contactList = SendContactViewController(dcContext: dcContext)
        contactList.delegate = self

        let navigationController = UINavigationController(rootViewController: contactList)
        if #available(iOS 15.0, *) {
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.large(), .medium()]
            }
        }

        present(navigationController, animated: true)
    }

    private func locationStreamingButtonPressed() {
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
        let action = UIAlertAction(title: String.localized(key), style: .default, handler: { [weak self] _ in
            self?.locationStreamingFor(seconds: duration)
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
        if !messageInputBar.inputTextView.isFirstResponder {
            becomeFirstResponder()
            messageInputBar.inputTextView.becomeFirstResponder()
        } else if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
                UIAccessibility.post(notification: .layoutChanged, argument: self?.messageInputBar.inputTextView)
            })
        }
    }

    private func stageVCard(url: URL) {
        draft.setAttachment(viewType: DC_MSG_VCARD, path: url.relativePath)
        configureDraftArea(draft: draft)
        focusInputTextView()
        FileHelper.deleteFileAsync(atPath: url.relativePath)
    }

    private func stageDocument(url: NSURL) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.draft.setAttachment(viewType: url.pathExtension == "xdc" ? DC_MSG_WEBXDC : DC_MSG_FILE, path: url.relativePath)
            self.configureDraftArea(draft: self.draft)
            self.focusInputTextView()
            FileHelper.deleteFileAsync(atPath: url.relativePath)
        }
    }

    private func stageVideo(url: NSURL) {
        self.draft.setAttachment(viewType: DC_MSG_VIDEO, path: url.relativePath)
        self.configureDraftArea(draft: self.draft)
        self.focusInputTextView()
        FileHelper.deleteFileAsync(atPath: url.relativePath)
    }

    private func stageImage(url: NSURL) {
        DispatchQueue.global().async { [weak self] in
            if let image = ImageFormat.loadImageFrom(url: url as URL) {
                self?.stageImage(image)
            }
        }
    }

    private func stageImage(_ image: UIImage) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            guard draft.sendEditRequestFor == nil else { return }
            guard !image.hasStickerLikeProperties else {
                return self.sendSticker(image)
            }
            if let pathInCachesDir = ImageFormat.saveImage(image: image, directory: .cachesDirectory) {
                DispatchQueue.main.async {
                    if pathInCachesDir.suffix(4).contains(".gif") {
                        self.draft.setAttachment(viewType: DC_MSG_GIF, path: pathInCachesDir)
                    } else {
                        self.draft.setAttachment(viewType: DC_MSG_IMAGE, path: pathInCachesDir)
                    }
                    self.configureDraftArea(draft: self.draft)
                    self.focusInputTextView()
                    FileHelper.deleteFileAsync(atPath: pathInCachesDir)
                }
            }
        }
    }

    private func sendImage(_ image: UIImage, message: String? = nil) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            if let path = ImageFormat.saveImage(image: image, directory: .cachesDirectory) {
                self.sendAttachmentMessage(viewType: DC_MSG_IMAGE, filePath: path, message: message)
                FileHelper.deleteFileAsync(atPath: path)
            }
        }
    }

    private func sendVideo(url: URL, message: String? = nil) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            self.sendAttachmentMessage(viewType: DC_MSG_VIDEO, filePath: url.relativePath, message: message)
            FileHelper.deleteFileAsync(atPath: url.relativePath)
        }
    }


    private func sendSticker(_ image: UIImage) {
        DispatchQueue.global().async { [weak self] in
            // stickers may be huge when drag'n'dropped from photo-recognition, scale down to a reasonable size
            let image = image.scaleDownImage(toMax: 300) ?? image

            guard let self, let path = ImageFormat.saveImage(image: image, directory: .cachesDirectory) else { return }

            if self.draft.draftMsg != nil {
                self.draft.setAttachment(viewType: DC_MSG_STICKER, path: path)
            }
            self.sendAttachmentMessage(viewType: DC_MSG_STICKER, filePath: path, message: nil, quoteMessage: self.draft.quoteMessage)

            FileHelper.deleteFileAsync(atPath: path)
            self.draft.clear()
            DispatchQueue.main.async {
                self.draftArea.quotePreview.cancel()
            }
        }
    }

    private func sendAttachmentMessage(viewType: Int32, filePath: String, fileName: String? = nil, message: String? = nil, quoteMessage: DcMsg? = nil) {
        let msg = draft.draftMsg ?? dcContext.newMessage(viewType: viewType)
        msg.setFile(filepath: filePath, fileName: fileName)
        msg.text = (message ?? "").isEmpty ? nil : message
        msg.quoteMessage = quoteMessage

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

    private func info(for msgId: Int) {
        let msg = self.dcContext.getMessage(id: msgId)
        navigationController?.pushViewController(MessageInfoViewController(dcContext: self.dcContext, message: msg), animated: true)
    }

    private func forward(_ msgId: Int) {
        let msg = dcContext.getMessage(id: msgId)
        RelayHelper.shared.setForwardMessages(messageIds: [msg.id])
        navigationController?.popToRootViewController(animated: true)
    }

    private func reply(_ msgId: Int) {
        replyToMessage(msgId)
    }

    private func editSentMessage(_ msgId: Int) {
        let message = dcContext.getMessage(id: msgId)

        draft.clear()
        draft.sendEditRequestFor = message.id
        configureDraftArea(draft: draft)
        messageInputBar.inputTextView.text = message.text
        focusInputTextView()
    }

    private func toggleSave(_ msgId: Int) {
        let message = dcContext.getMessage(id: msgId)
        if message.savedMessageId != 0 {
            dcContext.deleteMessage(msgId: message.savedMessageId)
        } else {
            dcContext.saveMessages(with: [msgId])
        }
    }

    private func shareSingle(_ msgId: Int) {
        Utils.share(message: dcContext.getMessage(id: msgId), parentViewController: self, sourceView: view)
    }

    private func resendSingle(_ msgId: Int) {
        dcContext.resendMessages(msgIds: [msgId])
    }

    private func deleteSingle(_ msgId: Int) {
        askToDeleteMessages(ids: [msgId])
    }

    private func copyTextToClipboard(_ msgId: Int) {
        copyTextToClipboard(ids: [msgId])
    }
    private func copyImageToClipboard(_ msgId: Int) {
        copyImagesToClipboard(ids: [msgId])
    }

    private func cancelSearch() {
        if searchController.isActive {
            searchController.isActive = false
            configureDraftArea(draft: draft)
            becomeFirstResponder()
            navigationItem.searchController = nil
            reloadData()
        }
    }

    private func selectMore(at indexPath: IndexPath) {
        cancelSearch()
        setEditing(isEditing: true, selectedAtIndexPath: indexPath)
        if UIAccessibility.isVoiceOverRunning {
            forceVoiceOverFocussingCell(at: indexPath, postingFinished: nil)
        }
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

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let id = messageIds[indexPath.row]
        return id != DC_MSG_ID_DAYMARKER && id != DC_MSG_ID_MARKER1
    }
}

extension ChatViewController {

    func tableView(_ tableView: UITableView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        guard let messageId = configuration.identifier as? NSString, let index = messageIds.firstIndex(of: messageId.integerValue) else { return }

        let indexPath = IndexPath(row: index, section: 0)

        guard let cell = tableView.cellForRow(at: indexPath) as? BaseMessageCell else { return }

        cell.messageBackgroundContainer.isHidden = true
        cell.reactionsView.isHidden = true
        contextMenuVisible = true

        updateScrollDownButtonVisibility()
    }

    func tableView(_ tableView: UITableView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
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

    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return targetedPreview(for: configuration)
    }

    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return targetedPreview(for: configuration)
    }

    private func targetedPreview(for configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let messageId = configuration.identifier as? NSString else { return nil }
        guard let index = messageIds.firstIndex(of: messageId.integerValue) else { return nil }
        // Using superview because tableView is transformed
        guard let superview = tableView.superview else { return nil }
        let indexPath = IndexPath(row: index, section: 0)

        guard let cell = tableView.cellForRow(at: indexPath) as? BaseMessageCell,
              let messageSnapshotView = cell.messageBackgroundContainer.snapshotView(afterScreenUpdates: false) else { return nil }

        let messageFrame = cell.messageBackgroundContainer.frame
        let messageCenter = CGPoint(x: messageFrame.midX, y: messageFrame.midY)
        let messageCenterInSuper = cell.convert(messageCenter, to: superview)
        let previewTarget = UIPreviewTarget(container: superview, center: messageCenterInSuper)

        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        
        // Apply the same rounded corners as the message bubble to preserve the shape during transition
        let radius: CGFloat = 16
        let rectCorners = cell.messageBackgroundContainer.rectCorners ?? UIRectCorner()
        let path = UIBezierPath(roundedRect: messageSnapshotView.bounds,
                                byRoundingCorners: rectCorners,
                                cornerRadii: CGSize(width: radius, height: radius))
        parameters.visiblePath = path
        
        let preview = UITargetedPreview(view: messageSnapshotView, parameters: parameters, target: previewTarget)
        
        self.lastContextMenuPreviewSnapshot = messageSnapshotView
        
        return preview
    }

    private func appendReactionItems(to menuElements: inout [UIMenuElement], indexPath: IndexPath) {
        let messageId = messageIds[indexPath.row]
        let myReactions = getMyReactions(messageId: messageId)
        var myReactionChecked = false

        for reaction in [DefaultReactions.thumbsUp, .thumbsDown, .heart] {
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
            if showPicker {
                reactionMessageId = messageId
                let pickerViewController = MCEmojiPickerViewController()
                pickerViewController.navigationItem.title = String.localized("react")
                pickerViewController.delegate = self

                let navigationController = UINavigationController(rootViewController: pickerViewController)
                if #available(iOS 15.0, *) {
                    if let sheet = navigationController.sheetPresentationController {
                        sheet.detents = [.medium(), .large()]
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

    private func isLinkTapped(indexPath: IndexPath, point: CGPoint) -> String? {
        if let cell = tableView.cellForRow(at: indexPath) as? BaseMessageCell {
            let label = cell.messageLabel.label
            let localTouchLocation = tableView.convert(point, to: label)
            return label.getCopyableLinkText(localTouchLocation)
        }
        return nil
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
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
                var moreOptions: [UIMenuElement] = []
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
                        UIAction.menuAction(localizationKey: "notify_reply_button", systemImageName: "arrowshape.turn.up.left", with: messageId, action: reply)
                    )
                }

                if canReplyPrivately(to: message) {
                    moreOptions.append(
                        UIAction.menuAction(localizationKey: "reply_privately", systemImageName: "arrowshape.turn.up.left", with: messageId, action: replyPrivatelyToMessage)
                    )
                }

                children.append(
                    UIAction.menuAction(localizationKey: "forward", systemImageName: "arrowshape.turn.up.forward", with: messageId, action: forward)
                )

                if message.isFromCurrentSender && message.hasText && !message.hasHtml && !message.isMarkerOrInfo && dcChat.canSend {
                    children.append(
                        UIAction.menuAction(localizationKey: "global_menu_edit_desktop", systemImageName: "pencil", with: messageId, action: editSentMessage)
                    )
                }

                if !dcChat.isSelfTalk && message.canSave {
                    if message.savedMessageId != 0 {
                        children.append(
                            UIAction.menuAction(localizationKey: "unsave", systemImageName: "bookmark.slash.fill", with: messageId, action: toggleSave)
                        )
                    } else {
                        children.append(
                            UIAction.menuAction(localizationKey: "save_desktop", systemImageName: "bookmark", with: messageId, action: toggleSave)
                        )
                    }
                }

                if let link = isLinkTapped(indexPath: indexPath, point: point) {
                    children.append(
                        UIAction.menuAction(localizationKey: "menu_copy_link_to_clipboard", systemImageName: "link", with: messageId, action: { _ in
                            UIPasteboard.general.string = link
                        })
                    )
                } else if let text = message.text, !text.isEmpty {
                    let copyTitle = message.file == nil ? "global_menu_edit_copy_desktop" : "menu_copy_text_to_clipboard"
                    children.append(
                        UIAction.menuAction(localizationKey: copyTitle, systemImageName: "doc.on.doc", with: messageId, action: copyTextToClipboard)
                    )
                }
                if message.image != nil {
                    moreOptions.append(
                        UIAction.menuAction(localizationKey: "menu_copy_image_to_clipboard", systemImageName: "photo.on.rectangle", with: messageId, action: copyImageToClipboard)
                    )
                }

                if message.file != nil {
                    moreOptions.append(UIAction.menuAction(localizationKey: "menu_share", systemImageName: "square.and.arrow.up", with: messageId, action: shareSingle))
                }

                children.append(
                    UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", with: messageId, action: deleteSingle)
                )

                if dcChat.canSend && message.isFromCurrentSender {
                    moreOptions.append(UIAction.menuAction(localizationKey: "resend", systemImageName: "paperplane", with: messageId, action: resendSingle))
                }

                moreOptions.append(UIAction.menuAction(localizationKey: "info", systemImageName: "info.circle", with: messageId, action: info))

                moreOptions.append(UIAction.menuAction(localizationKey: "select", systemImageName: "checkmark.circle", with: indexPath, action: selectMore))

                children.append(contentsOf: [
                    UIMenu(options: [.displayInline], children: [
                        UIMenu(title: String.localized("menu_more_options"), image: UIImage(systemName: "ellipsis.circle"), children: moreOptions)
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

extension ChatViewController: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard !tableView.isEditing else { return [] }
        // Prevent the drag preview from an showing upside down preview
        // by requiring a context menu to be shown first.
        guard lastContextMenuPreviewSnapshot != nil else { return [] }
        
        let messageId = messageIds[indexPath.row]
        let message = dcContext.getMessage(id: messageId)

        if let image = message.image {
            let dragItem = UIDragItem(itemProvider: .init(object: image))
            dragItem.previewProvider = {
                let view = UIImageView(image: image)
                view.frame.size = CGSize(width: 100, height: 100)
                view.contentMode = .scaleAspectFill
                return UIDragPreview(view: view)
            }
            return [dragItem]
        }

        return []
    }
}

extension ChatViewController {

    func showWebxdcViewFor(message: DcMsg, href: String? = nil) {
        let webxdcViewController = WebxdcViewController(dcContext: dcContext, messageId: message.id, href: href)
        navigationController?.pushViewController(webxdcViewController, animated: true)
    }

    func showMediaGalleryFor(message: DcMsg) {
        let msgIds = dcContext.getChatMedia(chatId: chatId, messageType: Int32(message.type), messageType2: 0, messageType3: 0)
        let index = msgIds.firstIndex(of: message.id) ?? 0

        navigationController?.pushViewController(PreviewController(dcContext: dcContext, type: .multi(msgIds, index)), animated: true)
    }

    func didTapVcard(msg: DcMsg) {
        guard let file = msg.file,
              let vcards = dcContext.parseVcard(path: file),
              let vcard = vcards.first else { return }

        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), vcard.displayName), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
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

    private func canSaveOrUnsaveMultiple() -> (Bool, Bool) { // returns tuple (canSaveOrUnsave, doSave)
        guard let rows = tableView.indexPathsForSelectedRows else { return (false, false) }
        let msgIds = rows.compactMap { messageIds[$0.row] }
        var doSave = false
        for msgId in msgIds {
            let msg = dcContext.getMessage(id: msgId)
            if !msg.canSave {
                return (false, false)
            } else if msg.savedMessageId == 0 {
                doSave = true // if in doubt, save
            }
        }
        return (true, doSave)
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

    private func evaluateMoreButton() {
        editingBar.moreButton.isEnabled = canSaveOrUnsaveMultiple().0 || canResend()
    }

    func setEditing(isEditing: Bool, selectedAtIndexPath: IndexPath? = nil) {
        self.tableView.setEditing(isEditing, animated: true)
        self.draft.isEditing = isEditing
        self.configureDraftArea(draft: self.draft)
        if let indexPath = selectedAtIndexPath {
            _ = handleSelection(indexPath: indexPath)
        }
        self.updateTitle()
        if refreshMessagesAfterEditing && isEditing == false {
            refreshMessages()
        }
        if isEditing && canBecomeFirstResponder {
            // Needed in case ChatViewController was never first responder
            becomeFirstResponder()
        } else if !isEditing && !canBecomeFirstResponder {
            // Needed in case ChatViewController should not be first responder anymore
            // so the keyboard is hidden and the tableView contentInset is recalculated
            resignFirstResponder()
        }
    }

    private func setDefaultBackgroundImage(view: UIImageView) {
        view.image = UIImage(named: traitCollection.userInterfaceStyle == .light ? "background_light" : "background_dark")
    }

    private func copyTextToClipboard(ids: [Int]) {
        var stringsToCopy = ""
        if ids.count > 1 {
            let sortedIds = ids.sorted()
            var lastSenderId: Int = -1
            for id in sortedIds {
                let msg = self.dcContext.getMessage(id: id)
                var textToCopy: String?
                if msg.type == DC_MSG_TEXT, let msgText = msg.text {
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
            if msg.type == DC_MSG_TEXT, let msgText = msg.text {
                stringsToCopy.append("\(msgText)")
            } else if let msgSummary = msg.summary(chars: 10000000) {
                stringsToCopy.append("\(msgSummary)")
            }
        }
        UIPasteboard.general.string = stringsToCopy
    }

    func copyImagesToClipboard(ids: [Int]) {
        let images = ids.map(dcContext.getMessage).compactMap(\.image)
        guard !images.isEmpty else { return }
        UIPasteboard.general.images = images
    }
}

// MARK: - BaseMessageCellDelegate
extension ChatViewController: BaseMessageCellDelegate {

    @objc func actionButtonTapped(indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }

        let msg = dcContext.getMessage(id: messageIds[indexPath.row])
        if msg.downloadState != DC_DOWNLOAD_DONE {
            dcContext.downloadFullMessage(id: msg.id)
        } else if msg.type == DC_MSG_WEBXDC {
            showWebxdcViewFor(message: msg)
        } else {
            let fullMessageViewController = FullMessageViewController(dcContext: dcContext, messageId: msg.id, isContactRequest: dcChat.isContactRequest)
            navigationController?.pushViewController(fullMessageViewController, animated: true)
        }
    }

    @objc func gotoOriginal(indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let savedMessage = dcContext.getMessage(id: messageIds[indexPath.row])

        let originalMessageId = savedMessage.originalMessageId
        if originalMessageId != 0 {
            let originalMessage = dcContext.getMessage(id: originalMessageId)
            appDelegate.appCoordinator.showChat(chatId: originalMessage.chatId, msgId: originalMessageId, animated: true, clearViewControllerStack: true)
        }
    }

    @objc func quoteTapped(indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }

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
        if handleSelection(indexPath: indexPath) { return }

        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        if message.state == DC_STATE_OUT_FAILED {
            info(for: message.id)
        } else if message.type == DC_MSG_VCARD {
            didTapVcard(msg: message)
        } else if message.type == DC_MSG_WEBXDC {
            showWebxdcViewFor(message: message)
        } else if message.type == DC_MSG_CALL {
            CallManager.shared.answerIncomingCall(forMessage: message.id, chatId: message.chatId, contextId: dcContext.id)
        }
    }

    @objc func phoneNumberTapped(number: String, indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }

        let sanitizedNumber = number.filter("0123456789".contains)
        if let phoneURL = URL(string: "tel://\(sanitizedNumber)") {
            UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
        }
    }

    @objc func commandTapped(command: String, indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }

        if let text = messageInputBar.inputTextView.text, !text.isEmpty {
            return
        }
        messageInputBar.inputTextView.text = command + " "
    }

    @objc func urlTapped(url: URL, indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }

        if Utils.isEmail(url: url) {
            let email = Utils.getEmailFrom(url)
            self.askToChatWith(email: email)
        } else if Utils.isProxy(url: url, dcContext: dcContext),
                  let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let appCoordinator = appDelegate.appCoordinator {
            appCoordinator.handleProxySelection(on: self, dcContext: dcContext, proxyURL: url.absoluteString)
        } else if url.isDeltaChatInvitation,
                  let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let appCoordinator = appDelegate.appCoordinator {
            appCoordinator.handleDeltaChatInvitation(url: url, from: self)
        } else {
            UIApplication.shared.open(url)
        }
    }

    @objc func imageTapped(indexPath: IndexPath, previewError: Bool) {
        if handleSelection(indexPath: indexPath) { return }

        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        if message.type != DC_MSG_STICKER {
            // prefer previewError over QLPreviewController.canPreview().
            // (the latter returns `true` for .webm - which is not wrong as _something_ is shown, even if the video cannot be played)
            if previewError && message.type == DC_MSG_VIDEO {
                let alert = UIAlertController(title: "To play this video, share to apps as VLC on the following page.", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("perm_continue"), style: .default, handler: { [weak self] _ in
                    self?.showMediaGalleryFor(message: message)
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
        navigationController?.pushViewController(ProfileViewController(dcContext, contactId: message.fromContactId), animated: true)
    }

    @objc func reactionsTapped(indexPath: IndexPath) {
        guard let reactions = dcContext.getMessageReactions(messageId: messageIds[indexPath.row]) else { return }

        let reactionsOverview = ReactionsOverviewViewController(reactions: reactions, context: dcContext)
        reactionsOverview.delegate = self
        let navigationController = UINavigationController(rootViewController: reactionsOverview)
        if #available(iOS 15.0, *) {
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.medium()]
            }
        }

        self.present(navigationController, animated: true)
    }

    @objc func statusTapped(indexPath: IndexPath) {
        if handleSelection(indexPath: indexPath) { return }

        let message = dcContext.getMessage(id: messageIds[indexPath.row])
        if message.state == DC_STATE_OUT_FAILED {
            info(for: message.id)
        }
    }
}

// MARK: - MediaPickerDelegate
extension ChatViewController: MediaPickerDelegate {
    func onVideoSelected(url: NSURL) {
        DispatchQueue.main.async {
            let url = url as URL
            let progressAlertHandler = ProgressAlertHandler()
            progressAlertHandler.dataSource = self
            progressAlertHandler.showProgressAlert(title: nil, dcContext: self.dcContext)
            DispatchQueue.global().async {
                url.convertToMp4(completionHandler: { [weak self] url, error in
                    DispatchQueue.main.async { [weak self] in
                        if let url, !progressAlertHandler.cancelled {
                            self?.stageVideo(url: (url as NSURL))
                            progressAlertHandler.updateProgressAlertSuccess()
                        } else if let error {
                            progressAlertHandler.updateProgressAlert(error: error.localizedDescription)
                        }
                    }
                })
            }
        }
    }

    func onImageSelected(url: NSURL) {
        stageImage(url: url)
    }

    func onImageSelected(image: UIImage) {
        stageImage(image)
    }

    func onMediaSelected(mediaPicker: MediaPicker, itemProviders: [NSItemProvider], sendAsFile: Bool) {
        if itemProviders.count > 1 {

            // send multiple selected item in one go directly
            // (sendAsFile can be ignored as forced to be only a single file at showFilesLibrary()
            let message = String.localized(stringID: "ask_send_files_to_chat", parameter: itemProviders.count, dcChat.name)
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("menu_send"), style: .default) { [weak self] _ in
                guard let self = self else { return }
                let progressAlertHandler = ProgressAlertHandler()
                progressAlertHandler.dataSource = self
                progressAlertHandler.showProgressAlert(title: nil, dcContext: self.dcContext)
                var processed = 0
                func increaseProcessed() {
                    processed += 1
                    progressAlertHandler.updateProgressAlertValue(value: (processed*1000) / itemProviders.count)
                    if processed >= itemProviders.count {
                        progressAlertHandler.updateProgressAlertSuccess()
                    }
                }

                DispatchQueue.global().async {
                    for itemProvider in itemProviders {
                        if !progressAlertHandler.cancelled {
                            if itemProvider.canLoadVideo() {
                                itemProvider.loadCompressedVideo { [weak self] url, error in
                                    if let url, !progressAlertHandler.cancelled {
                                        self?.sendVideo(url: url)
                                    } else if let error {
                                        progressAlertHandler.updateProgressAlert(error: error.localizedDescription)
                                    }
                                    increaseProcessed()
                                }
                            } else if itemProvider.canLoadImage() {
                                itemProvider.loadImage { [weak self] image, error in
                                    if let image, !progressAlertHandler.cancelled {
                                        self?.sendImage(image)
                                    } else if let error {
                                        progressAlertHandler.updateProgressAlert(error: error.localizedDescription)
                                    }
                                    increaseProcessed()
                                }
                            }
                        }
                    }
                }
            })
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true)

        } else if let itemProvider = itemProviders.first {

            // stage a single selected item
            if sendAsFile {
                if let typeIdentifier = itemProvider.registeredTypeIdentifiers.first {
                    itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
                        if let url {
                            var copyURL = URL.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                            copyURL = FileHelper.copyIfPossible(src: url, dest: copyURL)
                            self?.stageDocument(url: copyURL as NSURL)
                        } else if let error {
                            self?.logAndAlert(error: error.localizedDescription)
                        }
                    }
                } else {
                    logAndAlert(error: "No types registered")
                }
            } else if itemProvider.canLoadVideo() {
                let progressAlertHandler = ProgressAlertHandler()
                progressAlertHandler.dataSource = self
                progressAlertHandler.showProgressAlert(title: nil, dcContext: self.dcContext)
                itemProvider.loadCompressedVideo { [weak self] url, error in
                    if let url, !progressAlertHandler.cancelled {
                        self?.stageVideo(url: (url as NSURL))
                        progressAlertHandler.updateProgressAlertSuccess()
                    } else if let error {
                        progressAlertHandler.updateProgressAlert(error: error.localizedDescription)
                    }
                }
            } else if itemProvider.canLoadImage() {
                itemProvider.loadImage { [weak self] image, error in
                    if let image {
                        self?.stageImage(image)
                    } else if let error {
                        self?.logAndAlert(error: error.localizedDescription)
                    }
                }
            }
        }
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
        let trimmedText = text.replacingOccurrences(of: "\u{FFFC}", with: "", options: .literal, range: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var doResignFirstResponder = false

        if let sendEditRequestFor = draft.sendEditRequestFor {
            dcContext.sendEditRequest(msgId: sendEditRequestFor, newText: text)
            doResignFirstResponder = true
        } else if let filePath = draft.attachment, let viewType = draft.viewType {
            switch viewType {
            case DC_MSG_GIF, DC_MSG_IMAGE, DC_MSG_FILE, DC_MSG_VIDEO, DC_MSG_WEBXDC, DC_MSG_VCARD:
                self.sendAttachmentMessage(viewType: viewType, filePath: filePath, fileName: draft.draftMsg?.filename, message: trimmedText, quoteMessage: draft.quoteMessage)
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

        if doResignFirstResponder {
            inputBar.inputTextView.resignFirstResponder()
        }
    }

    func inputBar(_ inputBar: InputBarAccessoryView, textViewTextDidChangeTo text: String) {
        draft.text = text
        evaluateInputBar(draft: draft)
    }
}

// MARK: - DraftPreviewDelegate
extension ChatViewController: DraftPreviewDelegate {
    func onCancelQuote() {
        if draft.sendEditRequestFor != nil {
            draft.clear()
            draftArea.cancel()
            messageInputBar.inputTextView.text = nil
            messageInputBar.inputTextView.resignFirstResponder()
        } else {
            draft.setQuote(quotedMsg: nil)
            configureDraftArea(draft: draft)
            focusInputTextView()
        }
    }

    func onCancelAttachment() {
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
                if draft.viewType == DC_MSG_IMAGE || draft.viewType == DC_MSG_VIDEO {
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

    func onMorePressed() -> UIMenu {
        var actions = [UIMenuElement]()
        if canResend() {
            actions.append(UIAction(title: String.localized("resend"), image: UIImage(systemName: "paperplane")) { [weak self] _ in
                self?.onResendActionPressed()
            })
        }
        let (canSaveOrUnsave, doSave) = canSaveOrUnsaveMultiple()
        if canSaveOrUnsave {
            actions.append(UIAction(title: String.localized(doSave ? "save_desktop" : "unsave"), image: UIImage(systemName: doSave ? "bookmark" : "bookmark.slash.fill")) { [weak self] _ in
                self?.onMultipleSaveOrUnsave(doSave: doSave)
            })
        }
        return UIMenu(children: actions)
    }

    func onForwardPressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let messageIdsToForward = rows.compactMap { messageIds[$0.row] }
            if !messageIdsToForward.isEmpty {
                RelayHelper.shared.setForwardMessages(messageIds: messageIdsToForward)
                self.navigationController?.popToRootViewController(animated: true)
            }
        }
    }

    @objc func onCancelPressed() {
        setEditing(isEditing: false)
    }

    func onCopyPressed() {
        if let rows = tableView.indexPathsForSelectedRows {
            let ids = rows.compactMap { messageIds[$0.row] }
            copyTextToClipboard(ids: ids)
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
        scrollToMessage(msgId: searchMessageIds[searchResultIndex], animated: true, scrollToText: searchController.searchBar.text)
        searchAccessoryBar.updateSearchResult(sum: self.searchMessageIds.count, position: searchResultIndex + 1)
        self.reloadData()
    }

    func onSearchNextPressed() {
        if searchResultIndex == searchMessageIds.count - 1 {
            searchResultIndex = 0
        } else {
            searchResultIndex += 1
        }
        scrollToMessage(msgId: searchMessageIds[searchResultIndex], animated: true, scrollToText: searchController.searchBar.text)
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
                        self.scrollToMessage(msgId: lastId, animated: true, scrollToText: searchText)
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
        cancelSearch()
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
}


// MARK: - QLPreviewControllerDelegate
extension ChatViewController: QLPreviewControllerDelegate {
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
        self.logAndAlert(error: String.localized("cannot_play_audio_file"))
    }
}

// MARK: - ChatInputTextViewPasteDelegate
extension ChatViewController: ChatInputTextViewPasteDelegate {
    func onImagePasted(image: UIImage) {
        stageImage(image)
    }
}

// MARK: - ChatDropInteractionDelegate
extension ChatViewController: ChatDropInteractionDelegate {
    func onImageDragAndDropped(image: UIImage) {
        stageImage(image)
    }

    func onVideoDragAndDropped(url: NSURL) {
        DispatchQueue.main.async { [weak self] in
            self?.stageVideo(url: url)
        }
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
              let vcardURL = prepareVCardData(vcardData) else { return }

        stageVCard(url: vcardURL)
    }

    private func prepareVCardData(_ vcardData: Data) -> URL? {
        guard let fileName = FileHelper.saveData(data: vcardData,
                                                 name: UUID().uuidString,
                                                 suffix: "vcf",
                                                 directory: .cachesDirectory),
              let vcardURL = URL(string: fileName) else {
            return nil
        }

        return vcardURL
    }
}

// MARK: - ReactionsOverviewViewControllerDelegate

extension ChatViewController: ReactionsOverviewViewControllerDelegate {
    func showContact(_ viewController: UIViewController, with contactId: Int) {
        viewController.dismiss(animated: true)
        navigationController?.pushViewController(ProfileViewController(dcContext, contactId: contactId), animated: true)
    }
}

// MARK: - ChatListViewControllerDataSource

extension ChatViewController: BackButtonUpdateable {
    func shouldUpdateBackButton(_ viewController: UIViewController, chatId: Int, accountId: Int) -> Bool {
        if chatId == self.chatId && accountId == dcContext.id {
            return false
        } else {
            return true
        }
    }
}

// MARK: - AppPickerViewControllerDelegate

extension ChatViewController: AppPickerViewControllerDelegate {
    func pickedApp(_ viewController: AppPickerViewController, fileURL url: URL) {
        draft.setAttachment(viewType: DC_MSG_WEBXDC, path: url.relativePath)
        configureDraftArea(draft: draft)
        focusInputTextView()
        FileHelper.deleteFileAsync(atPath: url.relativePath)
    }
}
