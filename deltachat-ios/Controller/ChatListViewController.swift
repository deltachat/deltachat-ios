import UIKit
import DcCore

protocol BackButtonUpdateable: AnyObject {
    func shouldUpdateBackButton(_ viewController: UIViewController, chatId: Int, accountId: Int) -> Bool
}

class ChatListViewController: UITableViewController {
    var viewModel: ChatListViewModel?
    let dcContext: DcContext
    internal let dcAccounts: DcAccounts
    var isArchive: Bool
    private var accountSwitchTransitioningDelegate: PartialScreenModalTransitioningDelegate!
    weak var backButtonUpdateableDataSource: BackButtonUpdateable?

    private weak var timer: Timer?

    private lazy var titleView: UILabel = {
        let view = UILabel()
        let navTapGesture = UITapGestureRecognizer(target: self, action: #selector(onNavigationTitleTapped))
        view.addGestureRecognizer(navTapGesture)
        view.isUserInteractionEnabled = true
        view.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        view.accessibilityTraits = .header
        return view
    }()

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        return searchController
    }()

    private let archiveCell = ContactCell()

    private lazy var newButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.compose, target: self, action: #selector(didPressNewChat))
        button.tintColor = DcColors.primary
        return button
    }()

    private lazy var proxyShieldButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "checkmark.shield"), style: .plain, target: self, action: #selector(ChatListViewController.showProxySettings))
        button.tintColor = DcColors.primary
        return button
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    private lazy var markReadButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("mark_as_read_short"), style: .plain, target: self, action: #selector(markReadPressed))
        return button
    }()

    private lazy var emptyStateLabel: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.isHidden = true
        return label
    }()

    private lazy var editingBar: ChatListEditingBar = {
        let editingBar = ChatListEditingBar()
        editingBar.translatesAutoresizingMaskIntoConstraints = false
        editingBar.delegate = self
        editingBar.showArchive = !isArchive
        return editingBar
    }()

    private lazy var accountButtonAvatar: InitialsBadge = {
        let badge = InitialsBadge(size: 37, accessibilityLabel: String.localized("switch_account"))
        badge.accessibilityTraits = .button
        let tapGestureRecognizer =  UITapGestureRecognizer(target: self, action: #selector(accountButtonTapped))
        badge.addGestureRecognizer(tapGestureRecognizer)
        return badge
    }()

    private lazy var accountButton: UIBarButtonItem = {
        return UIBarButtonItem(customView: accountButtonAvatar)
    }()

    private var editingConstraints: [NSLayoutConstraint]?

    init(dcContext: DcContext, dcAccounts: DcAccounts, isArchive: Bool) {
        self.dcContext = dcContext
        self.dcAccounts = dcAccounts
        self.isArchive = isArchive
        super.init(style: .plain)
        hidesBottomBarWhenPushed = isArchive
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            self.viewModel = ChatListViewModel(dcContext: self.dcContext, isArchive: isArchive)
            self.viewModel?.onChatListUpdate = self.handleChatListUpdate
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if !isArchive {
                    self.navigationItem.searchController = self.searchController
                    self.searchController.searchResultsUpdater = self.viewModel
                    self.searchController.searchBar.delegate = self
                }
                self.handleChatListUpdate()
            }
        }
        // use the same background color as for cells and esp. the first archive-link cell
        // to make things appear less outstanding.
        //
        // TODO: this initally also sets the color of the "navigation area",
        // however, when opening+closing a chat, it is a blurry grey.
        // the inconsistency seems to be releated to the line
        //   navigationController?.navigationBar.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance
        // in ChatViewController.swift - removing this, the color is preserved at the cost of more flickering ...
        // this needs more love :)
        self.view.backgroundColor = UIColor.systemBackground

        NotificationCenter.default.addObserver(self, selector: #selector(handleIncomingMessageOnAnyAccount(_:)), name: Event.incomingMessageOnAnyAccount, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleIncomingMessage), name: Event.incomingMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMessagesChanged), name: Event.messagesChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectivityChanged), name: Event.connectivityChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleContactsChanged), name: Event.contactsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMsgReadDeliveredReactionFailed), name: Event.messageReadDeliveredFailedReaction, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMessagesNoticed), name: Event.messagesNoticed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChatModified), name: Event.chatModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRelayHelperDidChange), name: Event.relayHelperDidChange, object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        setupSubviews()

        // update messages - for new messages, do not reuse or modify strings but create new ones.
        // it is not needed to keep all past update messages, however, when deleted, also the strings should be deleted.
        let deviceMsgLabel = "update_2_3_ios"
        if !dcAccounts.isFreshlyAdded(id: dcContext.id) {
            let msg = dcContext.newMessage(viewType: DC_MSG_TEXT)
            msg.text = String.localizedStringWithFormat(String.localized("update_2_0"), "https://delta.chat/donate")
            dcContext.addDeviceMessage(label: deviceMsgLabel, msg: msg)
        } else {
            dcContext.addDeviceMessage(label: deviceMsgLabel, msg: nil)
        }

        // if the device message was added already for another profile,
        // mark the chat as being read, including any welcome messages
        if UserDefaults.standard.string(forKey: Constants.Keys.lastDeviceMessageLabel) == deviceMsgLabel {
            let deviceChatId = dcContext.getChatIdByContactId(Int(DC_CONTACT_ID_DEVICE))
            if deviceChatId != 0 {
                dcContext.marknoticedChat(chatId: deviceChatId)
            }
        }
        UserDefaults.standard.set(deviceMsgLabel, forKey: Constants.Keys.lastDeviceMessageLabel)

        if dcContext.isAnyDatabaseEncrypted() {
            let msg = dcContext.newMessage(viewType: DC_MSG_TEXT)
            msg.text = "⚠️ \"Encrypted Profiles\" are unsupported!\n\n"
            +   "👉 To exit the experiment and avoid problems in future versions:\n\n"
            +   "- Open encrypted profile in the profile switcher (marked by \"⚠️\")\n\n"
            +   "- Do \"Settings / Chats and Media / Export Backup\"\n\n"
            +   "- In the profile switcher, do \"Add Profile / I Already Have a Profile / Restore from Backup\"\n\n"
            +   "- If successful, you'll have the profile duplicated. Only then, delete the encrypted one marked by \"⚠️\""
            dcContext.addDeviceMessage(label: "ios-encrypted-accounts-unsupported7", msg: msg)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // create view
        navigationItem.titleView = titleView
        updateTitle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopTimer()
    }

    // MARK: - Notifications

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        guard dcContext.id == notification.userInfo?["account_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateTitle()
        }
    }

    @objc private func handleContactsChanged(_ notification: Notification) {
        refreshInBg()
    }

    @objc private func handleMsgReadDeliveredReactionFailed(_ notification: Notification) {
        refreshInBg()
    }

    @objc private func handleChatModified(_ notification: Notification) {
        refreshInBg()
    }

    @objc private func handleMessagesNoticed(_ notification: Notification) {
        refreshInBg()
        DispatchQueue.main.async { [weak self] in
            self?.updateNextScreensBackButton()
        }
    }

    @objc private func handleMessagesChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let viewModel = self.viewModel,
               viewModel.searchActive,
               appDelegate.appIsInForeground() {
                viewModel.updateSearchResults(for: self.searchController)
            }

            self.refreshInBg()
        }
    }

    @objc private func handleIncomingMessage(_ notification: Notification) {
        refreshInBg()
    }

    @objc private func handleIncomingMessageOnAnyAccount(_ notification: Notification) {

        guard let userInfo = notification.userInfo,
              let chatId = userInfo["chat_id"] as? Int,
              let accountId = userInfo["account_id"] as? Int
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateAccountButton()
            self?.updateNextScreensBackButton(accountId: accountId, chatId: chatId)
        }
    }

    @objc private func handleRelayHelperDidChange(_ notification: Notification) {
        updateTitle()
        if RelayHelper.shared.isForwarding() || RelayHelper.shared.isSharing() {
            refreshInBg()
            quitSearch(animated: false)
            tableView.scrollToTop()
        }
    }
    private func setupSubviews() {
        emptyStateLabel.addCenteredTo(parentView: view)
        updateNextScreensBackButton()
    }

    private func updateNextScreensBackButton(accountId: Int? = nil, chatId: Int? = nil) {
        let numberOfUnreadMessages = DcAccounts.shared.getFreshMessageCount()

        if isArchive {
            navigationItem.backBarButtonItem = nil
            navigationItem.backButtonTitle = String.localized("chat_archived_label")
        } else if numberOfUnreadMessages > 0 {

            if let backButtonUpdateableDataSource, let accountId, let chatId,
               backButtonUpdateableDataSource.shouldUpdateBackButton(self, chatId: chatId, accountId: accountId) == false {
                return
            }

            let symbolName: String
            if numberOfUnreadMessages > 50 {
                symbolName = "circle.fill"
            } else {
                symbolName = "\(numberOfUnreadMessages).circle.fill"
            }

            navigationItem.backBarButtonItem = UIBarButtonItem(image: UIImage(systemName: symbolName), style: .plain, target: nil, action: nil)
        } else { // if numberOfUnreadMessages == 0
            navigationItem.backBarButtonItem = nil
            navigationItem.backButtonTitle = String.localized("pref_chats")
        }
    }

    @objc
    public func onNavigationTitleTapped() {
        titleView.isEnabled = false // immedidate feedback
        CATransaction.flush()

        self.navigationController?.pushViewController(ConnectivityViewController(dcContext: self.dcContext), animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // /immedidate feedback
            self.titleView.isEnabled = true
        }
    }

    // MARK: - configuration
    private func configureTableView() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        tableView.rowHeight = ContactCell.cellHeight
        tableView.allowsMultipleSelectionDuringEditing = true
    }

    private var isInitial = true
    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            if !isInitial {
                startTimer()
                handleChatListUpdate()
            }
            isInitial = false
        }
    }

    private var inBgRefresh = false
    private var needsAnotherBgRefresh = false
    private func refreshInBg() {
        if inBgRefresh {
            needsAnotherBgRefresh = true
        } else {
            inBgRefresh = true
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                // do at least one refresh, without inital delay
                // (refreshData() calls handleChatListUpdate() on main thread when done)
                self?.needsAnotherBgRefresh = false
                self?.viewModel?.refreshData()

                // do subsequent refreshes with a delay of 500ms
                while self?.needsAnotherBgRefresh != false {
                    usleep(500000)
                    self?.needsAnotherBgRefresh = false
                    self?.viewModel?.refreshData()
                }

                self?.inBgRefresh = false
            }
        }
    }

    @objc func applicationWillResignActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            stopTimer()
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0, indexPath.row == 0, let cellData = viewModel?.cellDataFor(section: 0, row: 0) {
            switch cellData.type {
            case .chat(let chatData):
                if chatData.chatId == DC_CHAT_ID_ARCHIVED_LINK {
                    return ContactCell.cellHeight * 0.7
                }
            default:
                break
            }
        }
        return ContactCell.cellHeight
    }

    // MARK: - actions
    @objc func didPressNewChat() {
        showNewChatController()
    }

    @objc func cancelButtonPressed() {
        if tableView.isEditing {
            self.setLongTapEditing(false)
        } else {
            let data = RelayHelper.shared.data
            RelayHelper.shared.finishRelaying()
            updateTitle()
            refreshInBg()
            if case .forwardMessages(ids: let forwardIds) = data, let returnToMsgId = forwardIds.first {
                showChat(chatId: dcContext.getMessage(id: returnToMsgId).chatId, highlightedMsg: returnToMsgId)
            }
        }
    }

    @objc func markReadPressed() {
        if isEditing {
            viewModel?.markUnreadSelectedChats(in: tableView.indexPathsForSelectedRows)
            setLongTapEditing(false)
        } else if isArchive {
            dcContext.marknoticedChat(chatId: Int(DC_CHAT_ID_ARCHIVED_LINK))
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            tableView.rowHeight = ContactCell.cellHeight
        }
    }

    func quitSearch(animated: Bool) {
        searchController.searchBar.text = nil
        self.viewModel?.endSearch()
        searchController.dismiss(animated: animated) {
            self.tableView.scrollToTop()
        }
    }

    @objc func showProxySettings() {
        let proxySettingsViewController = ProxySettingsViewController(dcContext: dcContext, dcAccounts: dcAccounts)
        navigationController?.pushViewController(proxySettingsViewController, animated: true)
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource

    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.numberOfSections ?? 0
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsIn(section: section) ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel else { return UITableViewCell() }

        let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)
        switch cellData.type {
        case .chat(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_ARCHIVED_LINK {
                let chatCell = archiveCell
                chatCell.updateCell(cellViewModel: cellData)
                chatCell.delegate = self
                return chatCell
            } else if let chatCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell {
                chatCell.updateCell(cellViewModel: cellData)
                chatCell.delegate = self
                return chatCell
            }
        case .contact:
            assert(viewModel.searchActive)
            if let contactCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell {
                contactCell.updateCell(cellViewModel: cellData)
                return contactCell
            }
        case .profile:
            assertionFailure("CellData type profile not allowed")
        }

        assertionFailure("This should never happen")
        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel?.titleForHeaderIn(section: section)
    }

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if !tableView.isEditing {
            return indexPath
        }
        guard let viewModel = viewModel else {
            return nil
        }

        let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)
        switch cellData.type {
        case .chat(let chatData):
            return chatData.chatId == DC_CHAT_ID_ARCHIVED_LINK ? nil : indexPath
        default:
            return indexPath
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            if tableView.indexPathsForSelectedRows == nil && !isDuringMultipleSelectionInteraction {
                setLongTapEditing(false)
            } else {
                updateTitleAndEditingBar()
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModel else {
            tableView.deselectRow(at: indexPath, animated: false)
            return
        }
        if tableView.isEditing {
            updateTitleAndEditingBar()
            return
        }

        let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)
        switch cellData.type {
        case .chat(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_ARCHIVED_LINK {
                showArchive(animated: true)
            } else {
                showChat(chatId: chatId, highlightedMsg: chatData.highlightMsgId)
            }
        case .contact(let contactData):
            let contactId = contactData.contactId
            if let chatId = contactData.chatId {
                showChat(chatId: chatId)
            } else {
                self.askToChatWith(contactId: contactId)
            }
        case .profile:
            assertionFailure("CellData type profile not allowed")
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let viewModel, let chatId = viewModel.chatIdFor(section: indexPath.section, row: indexPath.row) else { return nil }

        if chatId==DC_CHAT_ID_ARCHIVED_LINK {
            return nil
        }
        let chat = dcContext.getChat(chatId: chatId)

        let pinned = chat.visibility==DC_CHAT_VISIBILITY_PINNED
        let pinTitle = String.localized(pinned ? "unpin" : "pin")
        let pinAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
            self?.viewModel?.pinChatToggle(chatId: chat.id)
            self?.setEditing(false, animated: true)
            completionHandler(true)
        }
        pinAction.accessibilityLabel = pinTitle
        pinAction.backgroundColor = UIColor.systemGreen
        pinAction.image = Utils.makeImageWithText(image: UIImage(systemName: pinned ? "pin.slash" : "pin"), text: pinTitle)

        if dcContext.getUnreadMessages(chatId: chatId) > 0 {
            let markReadAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
                self?.dcContext.marknoticedChat(chatId: chatId)
                completionHandler(true)
            }
            markReadAction.accessibilityLabel = String.localized("mark_as_read_short")
            markReadAction.backgroundColor = UIColor.systemBlue
            let imageName = if #available(iOS 16, *) { "checkmark.message" } else { "checkmark.circle" }
            markReadAction.image = Utils.makeImageWithText(image: UIImage(systemName: imageName), text: String.localized("mark_as_read_short"))

            return UISwipeActionsConfiguration(actions: [markReadAction, pinAction])
        } else {
            let actions = UISwipeActionsConfiguration(actions: [pinAction])
            actions.performsFirstActionWithFullSwipe = false
            return actions
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let viewModel, let chatId = viewModel.chatIdFor(section: indexPath.section, row: indexPath.row) else { return nil }

        if chatId==DC_CHAT_ID_ARCHIVED_LINK {
            return nil
        }
        let chat = dcContext.getChat(chatId: chatId)

        let archived = chat.isArchived
        let archiveTitle: String = String.localized(archived ? "unarchive" : "archive")
        let archiveAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
            self?.viewModel?.archiveChatToggle(chatId: chatId)
            self?.setEditing(false, animated: true)
            completionHandler(true)
        }
        archiveAction.accessibilityLabel = archiveTitle
        archiveAction.backgroundColor = UIColor.lightGray
        archiveAction.image = Utils.makeImageWithText(image: UIImage(systemName: archived ? "tray.and.arrow.up" : "tray.and.arrow.down"), text: archiveTitle)

        let muteTitle = String.localized(chat.isMuted ? "menu_unmute" : "mute")
        let muteAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completionHandler in
            guard let self else { return }
            if chat.isMuted {
                dcContext.setChatMuteDuration(chatId: chatId, duration: 0)
                completionHandler(true)
            } else {
                MuteDialog.show(viewController: self) { [weak self] duration in
                    guard let self else { return }
                    dcContext.setChatMuteDuration(chatId: chatId, duration: duration)
                    completionHandler(true)
                }
            }
        }
        muteAction.accessibilityLabel = muteTitle
        muteAction.backgroundColor = UIColor.systemOrange
        muteAction.image = Utils.makeImageWithText(image: UIImage(systemName: chat.isMuted ? "speaker.wave.2" : "speaker.slash"), text: muteTitle)

        if viewModel.isMessageSearchResult(indexPath: indexPath) {
            return UISwipeActionsConfiguration(actions: [archiveAction, muteAction])
        } else {
            let deleteAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completionHandler in
                self?.showDeleteChatConfirmationAlert(chatId: chatId) {
                    completionHandler(true)
                }
            }
            deleteAction.accessibilityLabel = String.localized("delete")
            deleteAction.backgroundColor = UIColor.systemRed
            deleteAction.image = Utils.makeImageWithText(image: UIImage(systemName: "trash"), text: String.localized("delete"))
            return UISwipeActionsConfiguration(actions: [archiveAction, muteAction, deleteAction])
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        viewModel?.setEditing(editing)
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let viewModel = viewModel else { return false }
        if viewModel.searchActive {
            return true
        } else {
            guard let chatList = viewModel.chatList else { return false }
            return chatList.getChatId(index: indexPath.row) != DC_CHAT_ID_ARCHIVED_LINK
        }
    }

    private func canMultiSelect() -> Bool {
        guard let viewModel else { return false }
        return !viewModel.searchActive && !(RelayHelper.shared.isForwarding() || RelayHelper.shared.isSharing())
    }

    private var isDuringMultipleSelectionInteraction = false
    override func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        return canMultiSelect()
    }
    override func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        isDuringMultipleSelectionInteraction = true
        setLongTapEditing(true)
    }
    override func tableViewDidEndMultipleSelectionInteraction(_ tableView: UITableView) {
        isDuringMultipleSelectionInteraction = false
        if tableView.indexPathsForSelectedRows == nil {
            setLongTapEditing(false)
        }
    }

    func setLongTapEditing(_ editing: Bool, initialIndexPath: IndexPath? = nil) {
        setEditing(editing, animated: true)
        if editing {
            tableView.selectRow(at: initialIndexPath, animated: true, scrollPosition: .none)
            addEditingView()
            updateTitleAndEditingBar()
        } else {
            removeEditingView()
            updateTitle()
        }
    }

    private func addEditingView() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let tabBarController = appDelegate.window?.rootViewController as? UITabBarController,
              editingConstraints == nil else { return }

        if tabBarController.view.subviews.contains(tabBarController.tabBar) {
            // UITabBar is child of UITabBarController, let edit bar cover UITabBar (moving to the bottom would place it below UITabBar)
            tabBarController.view.addSubview(editingBar)
            editingConstraints = [
                editingBar.leadingAnchor.constraint(equalTo: tabBarController.tabBar.leadingAnchor),
                editingBar.trailingAnchor.constraint(equalTo: tabBarController.tabBar.trailingAnchor),
                editingBar.topAnchor.constraint(equalTo: tabBarController.tabBar.topAnchor),
                editingBar.bottomAnchor.constraint(equalTo: tabBarController.tabBar.bottomAnchor),
            ]
        } else {
            // UITabBar is somewhere else (eg. atop on newer iPad), move edit bar to the bottom
            guard let parentView = self.navigationController?.view else { return }
            parentView.addSubview(editingBar)
            editingConstraints = [
                editingBar.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
                editingBar.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
                editingBar.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
                editingBar.heightAnchor.constraint(equalToConstant: 72)
            ]
        }
        NSLayoutConstraint.activate(editingConstraints ?? [])
    }

    private func removeEditingView() {
        editingBar.removeFromSuperview()
        NSLayoutConstraint.deactivate(editingConstraints ?? [])
        editingConstraints = nil
    }

    /// Check if the view is in row-selection mode.
    /// isEditing alone is not sufficient as also true during swipe-edit.
    private func hasEditingView() -> Bool {
        return tableView.isEditing && editingConstraints != nil
    }

    private func updateAccountButton() {
        let unreadMessages = dcAccounts.getFreshMessageCount(skipCurrent: true)
        accountButtonAvatar.setUnreadMessageCount(unreadMessages)
        if unreadMessages > 0 {
            accountButtonAvatar.accessibilityLabel = "\(String.localized("switch_account")): \(String.localized(stringID: "n_messages", parameter: unreadMessages))"
        } else {
            accountButtonAvatar.accessibilityLabel = "\(String.localized("switch_account"))"
        }

        let contact = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF))
        let title = dcContext.displayname ?? dcContext.addr ?? ""
        accountButtonAvatar.setColor(contact.color)
        accountButtonAvatar.setName(title)
        if let image = contact.profileImage {
            accountButtonAvatar.setImage(image)
        }
    }

    private func updateProxyButton() {
        if dcContext.isProxyEnabled {
            proxyShieldButton.image = UIImage(systemName: "checkmark.shield")
        } else {
            proxyShieldButton.image = UIImage(systemName: "shield")
        }
    }

    @objc private func accountButtonTapped() {
        let viewController = ProfileSwitchViewController(dcAccounts: dcAccounts)
        let accountSwitchNavigationController = UINavigationController(rootViewController: viewController)
        if #available(iOS 15.0, *) {
            if let sheet = accountSwitchNavigationController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
            }
        } else {
            accountSwitchTransitioningDelegate = PartialScreenModalTransitioningDelegate(from: self, to: accountSwitchNavigationController)
            accountSwitchNavigationController.modalPresentationStyle = .custom
            accountSwitchNavigationController.transitioningDelegate = accountSwitchTransitioningDelegate
        }

        self.present(accountSwitchNavigationController, animated: true)
    }

    // MARK: updates
    private func updateTitleAndEditingBar() {
        updateTitle()
    }

    private func updateTitle() {
        titleView.accessibilityHint = String.localized("a11y_connectivity_hint")
        if RelayHelper.shared.isForwarding() || RelayHelper.shared.isSharing() {
            // multi-select is not allowed during forwarding
            titleView.text = RelayHelper.shared.dialogTitle
            if isArchive {
                navigationItem.setRightBarButtonItems(nil, animated: true)
            } else {
                navigationItem.setLeftBarButton(cancelButton, animated: true)
                navigationItem.setRightBarButtonItems([newButton], animated: true)
            }

        } else if isArchive {
            titleView.text = String.localized("chat_archived_label")
            if !handleMultiSelectionTitle() {
                navigationItem.setLeftBarButton(nil, animated: true)
                navigationItem.setRightBarButtonItems([markReadButton], animated: true)
            }
            updateMarkReadButton()
        } else {
            titleView.text = DcUtils.getConnectivityString(dcContext: dcContext, connectedString: String.localized("pref_chats"))
            if !handleMultiSelectionTitle() {
                navigationItem.setLeftBarButton(accountButton, animated: false)
                updateAccountButton()

                if dcContext.getProxies().isEmpty {
                    navigationItem.setRightBarButtonItems([newButton], animated: true)
                } else {
                    updateProxyButton()
                    navigationItem.setRightBarButtonItems([newButton, proxyShieldButton], animated: true)
                }

                if dcContext.getConnectivity() >= DC_CONNECTIVITY_CONNECTED {
                    titleView.accessibilityHint = "\(String.localized("connectivity_connected")): \(String.localized("a11y_connectivity_hint"))"
                }
            }
        }
        titleView.isUserInteractionEnabled = !tableView.isEditing
        titleView.sizeToFit()
    }

    func handleMultiSelectionTitle() -> Bool {
        if !hasEditingView() {
            return false
        }
        titleView.accessibilityHint = nil
        let cnt = tableView.indexPathsForSelectedRows?.count ?? 0
        titleView.text = String.localized(stringID: "n_selected", parameter: cnt)
        navigationItem.setLeftBarButton(cancelButton, animated: true)
        navigationItem.setRightBarButtonItems([markReadButton], animated: true)
        updateMarkReadButton()
        return true
    }

    func handleChatListUpdate() {
        if let viewModel, viewModel.isEditing {
            viewModel.setPendingChatListUpdate()
        } else if Thread.isMainThread {
            tableView.reloadData()
            handleEmptyStateLabel()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.tableView.reloadData()
                self.handleEmptyStateLabel()
            }
        }
        updateMarkReadButton()
    }
    
    func updateMarkReadButton() {
        if tableView.isEditing {
            self.markReadButton.isEnabled = viewModel?.hasAnyUnreadChatSelected(in: tableView.indexPathsForSelectedRows) ?? false
        } else if isArchive {
            self.markReadButton.isEnabled = dcContext.getUnreadMessages(chatId: Int(DC_CHAT_ID_ARCHIVED_LINK)) != 0
        }
    }

    private func handleEmptyStateLabel() {
        if let emptySearchText = viewModel?.emptySearchText {
            let text = String.localizedStringWithFormat(
                String.localized("search_no_result_for_x"),
                emptySearchText
            )
            emptyStateLabel.text = text
            emptyStateLabel.isHidden = false
        } else if isArchive && (viewModel?.numberOfRowsIn(section: 0) ?? 0) == 0 {
            emptyStateLabel.text = String.localized("archive_empty_hint")
            emptyStateLabel.isHidden = false
        } else {
            emptyStateLabel.text = nil
            emptyStateLabel.isHidden = true
        }
    }
    
    private func startTimer() {
        // check if the timer is not yet started
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            
            guard let self,
                  let appDelegate = UIApplication.shared.delegate as? AppDelegate
            else { return }
            
            if appDelegate.appIsInForeground() {
                self.handleChatListUpdate()
            } else {
                logger.warning("startTimer() must not be executed in background")
            }
        }
    }
    
    private func stopTimer() {
        // check if the timer is not already stopped
        if let timer = timer {
            timer.invalidate()
        }
        timer = nil
    }

    public func handleMailto(askToChat: Bool = true) {
        if case .mailto(address: let mailtoAddress, _) = RelayHelper.shared.data {
            let contactId = dcContext.lookupContactIdByAddress(mailtoAddress)
            if contactId != 0 && dcContext.getChatIdByContactId(contactId) != 0 {
                showChat(chatId: dcContext.getChatIdByContactId(contactId), animated: false)
            } else if askToChat {
                askToChatWith(address: mailtoAddress)
            } else {
                createAndShowNewChat(contactId: 0, email: mailtoAddress)
            }
        }
    }

    // MARK: - alerts
    private func showDeleteChatConfirmationAlert(chatId: Int, didDelete: (() -> Void)? = nil) {
        let alert = UIAlertController(
            title: nil,
            message: String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), dcContext.getChat(chatId: chatId).name),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { [weak self] _ in
            self?.deleteChat(chatId: chatId, animated: true)
            didDelete?()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showDeleteMultipleChatConfirmationAlert() {
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        if selectedCount == 0 {
            return
        }

        let message: String
        if selectedCount == 1,
           let chatIds = viewModel?.chatIdsFor(indexPaths: tableView.indexPathsForSelectedRows),
           let chatId = chatIds.first {
            message = String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), dcContext.getChat(chatId: chatId).name)
        } else {
            message = String.localized(stringID: "ask_delete_chat", parameter: selectedCount)
        }

        let alert = UIAlertController(title: nil, message: message, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { [weak self] _ in
            guard let self, let viewModel = self.viewModel else { return }
            viewModel.deleteChats(indexPaths: self.tableView.indexPathsForSelectedRows)
            self.setLongTapEditing(false)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func askToChatWith(address: String, contactId: Int = 0) {
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), address),
                                      message: nil,
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.createAndShowNewChat(contactId: contactId, email: address)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            if RelayHelper.shared.isMailtoHandling() {
                RelayHelper.shared.finishRelaying()
            }
        }))
        present(alert, animated: true, completion: nil)
    }

    private func createAndShowNewChat(contactId: Int, email: String) {
        var contactId = contactId
        if contactId == 0 {
            contactId = self.dcContext.createContact(name: nil, email: email)
        }
        self.showNewChat(contactId: contactId)
    }

    private func askToChatWith(contactId: Int) {
        let dcContact = dcContext.getContact(id: contactId)
        askToChatWith(address: dcContact.displayName, contactId: contactId)
    }

    private func deleteChat(chatId: Int, animated: Bool) {
        guard let viewModel = viewModel else { return }
        if !animated {
            viewModel.deleteChat(chatId: chatId)
            refreshInBg()
            return
        }

        if viewModel.searchActive {
            viewModel.deleteChat(chatId: chatId)
            viewModel.refreshData()
            viewModel.updateSearchResults(for: searchController)
            return
        }

        viewModel.deleteChat(chatId: chatId)
    }

    // MARK: - coordinator
    private func showNewChatController() {
        let newChatVC = NewChatViewController(dcContext: dcContext)
        navigationController?.pushViewController(newChatVC, animated: true)
    }

    func showChat(chatId: Int, highlightedMsg: Int? = nil, animated: Bool = true) {
        if searchController.isActive {
            searchController.searchBar.resignFirstResponder()
        }
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId, highlightedMsg: highlightedMsg)
        backButtonUpdateableDataSource = chatViewController
        updateNextScreensBackButton(accountId: dcContext.id, chatId: chatId)

        navigationController?.pushViewController(chatViewController, animated: animated)
    }

    public func showArchive(animated: Bool) {
        let controller = ChatListViewController(dcContext: dcContext, dcAccounts: dcAccounts, isArchive: true)
        navigationController?.pushViewController(controller, animated: animated)
    }

    private func showNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        showChat(chatId: Int(chatId))
    }
}

// MARK: - UISearchBarDelegate
extension ChatListViewController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        viewModel?.beginSearch()
        setLongTapEditing(false)
        return true
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // searchBar will be set to "" by system
        viewModel?.endSearch()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
           self.tableView.scrollToTop()
        }
    }

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        tableView.scrollToTop()
        return true
    }
}

// MARK: - ContactCellDelegate
extension ChatListViewController: ContactCellDelegate {
    func onLongTap(at indexPath: IndexPath) {
        if canMultiSelect() && !tableView.isEditing {
            guard let chatList = viewModel?.chatList else { return }
            if chatList.getChatId(index: indexPath.row) != Int(DC_CHAT_ID_ARCHIVED_LINK) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                setLongTapEditing(true, initialIndexPath: indexPath)
            }
        }
    }
}

// MARK: - ChatListEditingBarDelegate
extension ChatListViewController: ChatListEditingBarDelegate {
    func onDeleteButtonPressed() {
        showDeleteMultipleChatConfirmationAlert()
    }

    func onArchiveButtonPressed() {
        viewModel?.archiveChatsToggle(indexPaths: tableView.indexPathsForSelectedRows)
        setLongTapEditing(false)
    }

    func onMorePressed() -> UIMenu {
        guard let userDefaults = UserDefaults.shared, let viewModel else { return UIMenu() }
        let chatIds = viewModel.chatIdsFor(indexPaths: tableView.indexPathsForSelectedRows)
        var actions = [UIMenuElement]()

        if #available(iOS 17.0, *),
           chatIds.count == 1,
           let chatId = chatIds.first {

            let allHomescreenChatsIds: [Int] = userDefaults
                .getChatWidgetEntries()
                .filter { $0.accountId == dcContext.id }
                .compactMap { entry in
                    switch entry.type {
                    case .app: return nil
                    case .chat(let chatId): return chatId
                    }
                }

            let chatPresentInHomescreenWidget = allHomescreenChatsIds.contains(chatId)
            let action: UIAction
            if chatPresentInHomescreenWidget {
                action = UIAction(title: String.localized("remove_from_widget"), image: UIImage(systemName: "minus.square")) { [weak self] _ in
                    guard let self else { return }
                    userDefaults.removeChatFromHomescreenWidget(accountId: self.dcContext.id, chatId: chatId)
                    setLongTapEditing(false)
                }
            } else {
                action = UIAction(title: String.localized("add_to_widget"), image: UIImage(systemName: "plus.square")) { [weak self] _ in
                    guard let self else { return }
                    userDefaults.addChatToHomescreenWidget(accountId: self.dcContext.id, chatId: chatId)
                    setLongTapEditing(false)
                }
            }
            actions.append(action)
        }

        let onlyPinndedSelected = viewModel.hasOnlyPinnedChatsSelected(in: tableView.indexPathsForSelectedRows)
        let pinTitle = String.localized(onlyPinndedSelected ? "unpin" : "pin")
        let pinImage = UIImage(systemName: onlyPinndedSelected ? "pin.slash" : "pin")
        actions.append(UIAction(title: pinTitle, image: pinImage) { [weak self] _ in
            guard let self else { return }
            viewModel.pinChatsToggle(indexPaths: tableView.indexPathsForSelectedRows)
            setLongTapEditing(false)
        })

        if viewModel.hasAnyUnmutedChatSelected(in: tableView.indexPathsForSelectedRows) {
            actions.append(UIAction(title: String.localized("menu_mute"), image: UIImage(systemName: "speaker.slash")) { [weak self] _ in
                guard let self else { return }
                MuteDialog.show(viewController: self) { [weak self] duration in
                    guard let self else { return }
                    viewModel.setMuteDurations(in: tableView.indexPathsForSelectedRows, duration: duration)
                    setLongTapEditing(false)
                }
            })
        } else {
            actions.append(UIAction(title: String.localized("menu_unmute"), image: UIImage(systemName: "speaker.wave.2")) { [weak self] _ in
                guard let self else { return }
                viewModel.setMuteDurations(in: tableView.indexPathsForSelectedRows, duration: 0)
                setLongTapEditing(false)
            })
        }

        return UIMenu(children: actions)
    }
}
