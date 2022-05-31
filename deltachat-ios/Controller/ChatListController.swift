import UIKit
import DcCore

class ChatListController: UITableViewController {
    var viewModel: ChatListViewModel?
    let dcContext: DcContext
    var isArchive: Bool

    private let chatCellReuseIdentifier = "chat_cell"
    private let deadDropCellReuseIdentifier = "deaddrop_cell"
    private let contactCellReuseIdentifier = "contact_cell"

    private var msgChangedObserver: NSObjectProtocol?
    private var msgsNoticedObserver: NSObjectProtocol?
    private var incomingMsgObserver: NSObjectProtocol?
    private var chatModifiedObserver: NSObjectProtocol?
    private var contactsChangedObserver: NSObjectProtocol?
    private var connectivityChangedObserver: NSObjectProtocol?
    private var msgChangedSearchResultObserver: NSObjectProtocol?

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

    private lazy var archiveCell: ActionCell = {
        let actionCell = ActionCell()
        return actionCell
    }()

    private lazy var newButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.compose, target: self, action: #selector(didPressNewChat))
        button.tintColor = DcColors.primary
        return button
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    private lazy var emptyStateLabel: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.isHidden = true
        return label
    }()

    init(dcContext: DcContext, isArchive: Bool) {
        self.dcContext = dcContext
        self.isArchive = isArchive
        super.init(style: .grouped)
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            self.viewModel = ChatListViewModel(dcContext: self.dcContext, isArchive: isArchive)
            self.viewModel?.onChatListUpdate = self.handleChatListUpdate
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !isArchive {
                    self.navigationItem.searchController = self.searchController
                    self.searchController.searchResultsUpdater = self.viewModel
                    self.searchController.searchBar.delegate = self
                }
                self.handleChatListUpdate()
            }
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if !isArchive {
            navigationItem.rightBarButtonItem = newButton
        }
        configureTableView()
        setupSubviews()

        // update messages - for new messages, do not reuse or modify strings but create new ones.
        // it is not needed to keep all past update messages, however, when deleted, also the strings should be deleted.
        let msg = dcContext.newMessage(viewType: DC_MSG_TEXT)
        msg.text = String.localized("update_1_30")
        dcContext.addDeviceMessage(label: "update_1_30a_ios", msg: msg)
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            // logger.debug("chat observer: remove")
            removeObservers()
        } else {
            // logger.debug("chat observer: setup")
            addObservers()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // create view
        navigationItem.titleView = titleView
        updateTitle()

        if RelayHelper.sharedInstance.isForwarding() {
            quitSearch(animated: false)
            tableView.scrollToTop()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTimer()
        refreshInBg() // at least required for sharing from DC -> DC
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopTimer()
    }

    // MARK: - setup
    private func addObservers() {
        let nc = NotificationCenter.default
        
        connectivityChangedObserver = nc.addObserver(forName: dcNotificationConnectivityChanged,
                                                     object: nil,
                                                     queue: nil) { [weak self] _ in
                                                        self?.updateTitle()
                                                     }

        msgChangedSearchResultObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil,
            queue: nil) { [weak self] _ in
            guard let self = self else { return }
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let viewModel = self.viewModel,
               viewModel.searchActive,
               appDelegate.appIsInForeground() {
                viewModel.updateSearchResults(for: self.searchController)
            }
        }

        msgChangedObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.refreshInBg()
            }
        msgsNoticedObserver = nc.addObserver(
            forName: dcMsgsNoticed,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.refreshInBg()
            }
        incomingMsgObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.refreshInBg()
            }
        chatModifiedObserver = nc.addObserver(
            forName: dcNotificationChatModified,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.refreshInBg()
            }
        contactsChangedObserver = nc.addObserver(
            forName: dcNotificationContactChanged,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.refreshInBg()
            }

        nc.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        nc.addObserver(
            self,
            selector: #selector(applicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil)
    }

    private func removeObservers() {
        let nc = NotificationCenter.default
        // remove observers with a block
        if let msgChangedResultObserver = self.msgChangedSearchResultObserver {
            nc.removeObserver(msgChangedResultObserver)
        }
        if let msgChangedObserver = self.msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let incomingMsgObserver = self.incomingMsgObserver {
            nc.removeObserver(incomingMsgObserver)
        }
        if let msgsNoticedObserver = self.msgsNoticedObserver {
            nc.removeObserver(msgsNoticedObserver)
        }
        if let chatModifiedObserver = self.chatModifiedObserver {
            nc.removeObserver(chatModifiedObserver)
        }
        if let contactsChangedObserver = self.contactsChangedObserver {
            nc.removeObserver(contactsChangedObserver)
        }
        if let connectivityChangedObserver = self.connectivityChangedObserver {
            nc.removeObserver(connectivityChangedObserver)
        }
        // remove non-block observers
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    private func setupSubviews() {
        emptyStateLabel.addCenteredTo(parentView: view)
        navigationItem.backButtonTitle = isArchive ? String.localized("chat_archived_chats_title") : String.localized("pref_chats")
    }

    @objc
    public func onNavigationTitleTapped() {
        logger.debug("on navigation title tapped")
        let connectivityViewController = ConnectivityViewController(dcContext: dcContext)
        navigationController?.pushViewController(connectivityViewController, animated: true)
    }

    // MARK: - configuration
    private func configureTableView() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: chatCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: deadDropCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        tableView.rowHeight = ContactCell.cellHeight
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
    
    // MARK: - actions
    @objc func didPressNewChat() {
        showNewChatController()
    }

    @objc func cancelButtonPressed() {
        // cancel forwarding
        RelayHelper.sharedInstance.cancel()
        updateTitle()
        refreshInBg()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            tableView.rowHeight = ContactCell.cellHeight
        }
    }
    private func quitSearch(animated: Bool) {
        searchController.searchBar.text = nil
        self.viewModel?.endSearch()
        searchController.dismiss(animated: animated) {
            self.tableView.scrollToTop()
        }
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource

    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.numberOfSections ?? 0
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsIn(section: section) ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else {
            return UITableViewCell()
        }
        let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)
        switch cellData.type {
        case .chat(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_ARCHIVED_LINK {
                archiveCell.actionTitle = dcContext.getChat(chatId: chatId).name
                archiveCell.backgroundColor = DcColors.chatBackgroundColor
                return archiveCell
            } else if let chatCell = tableView.dequeueReusableCell(withIdentifier: chatCellReuseIdentifier, for: indexPath) as? ContactCell {
                // default chatCell
                chatCell.updateCell(cellViewModel: cellData)
                return chatCell
            }
        case .contact:
            safe_assert(viewModel.searchActive)
            if let contactCell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ContactCell {
                contactCell.updateCell(cellViewModel: cellData)
                return contactCell
            }
        case .profile:
            safe_fatalError("CellData type profile not allowed")
        }
        safe_fatalError("Could not find/dequeue or recycle UITableViewCell.")
        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel?.titleForHeaderIn(section: section)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let viewModel = viewModel else {
            tableView.deselectRow(at: indexPath, animated: false)
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
            safe_fatalError("CellData type profile not allowed")
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard let viewModel = viewModel else { return [] }

        guard let chatId = viewModel.chatIdFor(section: indexPath.section, row: indexPath.row) else {
            return []
        }

        if chatId==DC_CHAT_ID_ARCHIVED_LINK {
            return []
            // returning nil may result in a default delete action,
            // see https://forums.developer.apple.com/thread/115030
        }
        let chat = dcContext.getChat(chatId: chatId)
        let archived = chat.isArchived
        let archiveActionTitle: String = String.localized(archived ? "unarchive" : "archive")

        let archiveAction = UITableViewRowAction(style: .destructive, title: archiveActionTitle) { [weak self] _, _ in
            self?.viewModel?.archiveChatToggle(chatId: chatId)
        }
        archiveAction.backgroundColor = UIColor.lightGray

        let pinned = chat.visibility==DC_CHAT_VISIBILITY_PINNED
        let pinAction = UITableViewRowAction(style: .destructive, title: String.localized(pinned ? "unpin" : "pin")) { [weak self] _, _ in
            self?.viewModel?.pinChatToggle(chatId: chat.id)
        }
        pinAction.backgroundColor = UIColor.systemGreen

        let deleteAction = UITableViewRowAction(style: .normal, title: String.localized("delete")) { [weak self] _, _ in
            self?.showDeleteChatConfirmationAlert(chatId: chatId)
        }
        deleteAction.backgroundColor = UIColor.systemRed

        return [archiveAction, pinAction, deleteAction]
    }

    // MARK: updates
    private func updateTitle() {
        titleView.accessibilityHint = String.localized("a11y_connectivity_hint")
        if RelayHelper.sharedInstance.isForwarding() {
            titleView.text = String.localized("forward_to")
            if !isArchive {
                navigationItem.setLeftBarButton(cancelButton, animated: true)
            }
        } else if isArchive {
            titleView.text = String.localized("chat_archived_chats_title")
            navigationItem.setLeftBarButton(nil, animated: true)
           
        } else {
            titleView.text = DcUtils.getConnectivityString(dcContext: dcContext, connectedString: String.localized("pref_chats"))
            if dcContext.getConnectivity() >= DC_CONNECTIVITY_CONNECTED {
                titleView.accessibilityHint = "\(String.localized("connectivity_connected")): \(String.localized("a11y_connectivity_hint"))"
            }
            navigationItem.setLeftBarButton(nil, animated: true)
        }
        titleView.sizeToFit()
    }

    func handleChatListUpdate() {
        if Thread.isMainThread {
            tableView.reloadData()
            handleEmptyStateLabel()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.tableView.reloadData()
                self.handleEmptyStateLabel()
            }
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
            
            guard let self = self,
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

    public func handleMailto() {
        if let mailtoAddress = RelayHelper.sharedInstance.mailtoAddress {
            // FIXME: the line below should work
            // var contactId = dcContext.lookupContactIdByAddress(mailtoAddress)

            // workaround:
            let contacts: [Int] = dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: mailtoAddress)
            let index = contacts.firstIndex(where: { dcContext.getContact(id: $0).email == mailtoAddress }) ?? -1
            var contactId = 0
            if index >= 0 {
                contactId = contacts[index]
            }

            if contactId != 0 && dcContext.getChatIdByContactId(contactId: contactId) != 0 {
                showChat(chatId: dcContext.getChatIdByContactId(contactId: contactId), animated: false)
            } else {
                askToChatWith(address: mailtoAddress)
            }
        }
    }

    // MARK: - alerts
    private func showDeleteChatConfirmationAlert(chatId: Int) {
        let alert = UIAlertController(
            title: nil,
            message: String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), dcContext.getChat(chatId: chatId).name),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.deleteChat(chatId: chatId, animated: true)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func askToChatWith(address: String, contactId: Int = 0) {
        var contactId = contactId
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), address),
                                      message: nil,
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            if contactId == 0 {
                contactId = self.dcContext.createContact(name: nil, email: address)
            }
            self.showNewChat(contactId: contactId)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            if RelayHelper.sharedInstance.isMailtoHandling() {
                RelayHelper.sharedInstance.finishMailto()
            }
        }))
        present(alert, animated: true, completion: nil)
    }


    private func askToChatWith(contactId: Int) {
        let dcContact = dcContext.getContact(id: contactId)
        askToChatWith(address: dcContact.nameNAddr, contactId: contactId)
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
        let chatVC = ChatViewController(dcContext: dcContext, chatId: chatId, highlightedMsg: highlightedMsg)
        navigationController?.pushViewController(chatVC, animated: animated)
    }

    public func showArchive(animated: Bool) {
        let controller = ChatListController(dcContext: dcContext, isArchive: true)
        navigationController?.pushViewController(controller, animated: animated)
    }

    private func showNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        showChat(chatId: Int(chatId))
    }
}

// MARK: - uisearchbardelegate
extension ChatListController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        viewModel?.beginSearch()
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
