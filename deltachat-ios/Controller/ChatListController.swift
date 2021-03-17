import UIKit
import DcCore

class ChatListController: UITableViewController {
    let viewModel: ChatListViewModelProtocol
    let dcContext: DcContext

    private let chatCellReuseIdentifier = "chat_cell"
    private let deadDropCellReuseIdentifier = "deaddrop_cell"
    private let contactCellReuseIdentifier = "contact_cell"

    private var msgChangedObserver: Any?
    private var msgsNoticedObserver: Any?
    private var incomingMsgObserver: Any?
    private var viewChatObserver: Any?
    private var foregroundObserver: Any?
    private var backgroundObserver: Any?

    private weak var timer: Timer?

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.searchBar.delegate = self
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

    private lazy var emptySearchStateLabel: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.isHidden = false
        return label
    }()

    init(dcContext: DcContext, viewModel: ChatListViewModelProtocol) {
        self.viewModel = viewModel
        self.dcContext = dcContext
        if viewModel.isArchive {
            super.init(nibName: nil, bundle: nil)
        } else {
            super.init(style: .grouped)
        }
        viewModel.onChatListUpdate = handleChatListUpdate // register listener
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = newButton
        if !viewModel.isArchive {
            navigationItem.searchController = searchController
        }
        configureTableView()
        setupSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // update messages - for new messages, do not reuse or modify strings but create new ones.
        // it is not needed to keep all past update messages, however, when deleted, also the strings should be deleted.
        let msg = DcMsg(viewType: DC_MSG_TEXT)
        msg.text = "What's new in 1.16?\n"
            + "\n"
            + "✍️ Add text to images and files before sending\n"
            + "\n"
            + "🎨 Draw on images before sending (tap the image selected for sending, then the icon in the upper right corner)\n"
            + "\n"
            + "✅ ☑️ Multi-select messages and forward or delete them with one tap "
            + "(long tap on message, admire the new, much nicer context menu, then \"Select more\")\n"
            + "\n"
            + "As always, see https://delta.chat/blog for more news and updates."
        dcContext.addDeviceMessage(label: "update_1_16g_ios", msg: msg)

        // create view
        updateTitle()
        viewModel.refreshData()

        if RelayHelper.sharedInstance.isForwarding() {
            quitSearch(animated: false)
            tableView.scrollToTop()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTimer()
        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.viewModel.refreshData()

        }
        msgsNoticedObserver = nc.addObserver(
            forName: dcMsgsNoticed,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.viewModel.refreshData()

        }
        incomingMsgObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil,
            queue: nil) { [weak self] _ in
                self?.viewModel.refreshData()
        }
        viewChatObserver = nc.addObserver(
            forName: dcNotificationViewChat,
            object: nil,
            queue: nil) { [weak self] notification in
                if let chatId = notification.userInfo?["chat_id"] as? Int {
                    self?.showChat(chatId: chatId)
                }
        }
        foregroundObserver = nc.addObserver(self,
                                            selector: #selector(applicationDidBecomeActive(_:)),
                                            name: UIApplication.didBecomeActiveNotification,
                                            object: nil)
        backgroundObserver = nc.addObserver(self,
                                            selector: #selector(applicationWillResignActive(_:)),
                                            name: UIApplication.willResignActiveNotification,
                                            object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopTimer()

        let nc = NotificationCenter.default
        if let msgChangedObserver = self.msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let incomingMsgObserver = self.incomingMsgObserver {
            nc.removeObserver(incomingMsgObserver)
        }
        if let viewChatObserver = self.viewChatObserver {
            nc.removeObserver(viewChatObserver)
        }
        if let msgsNoticedObserver = self.msgsNoticedObserver {
            nc.removeObserver(msgsNoticedObserver)
        }
        if let foregroundObserver = self.foregroundObserver {
            nc.removeObserver(foregroundObserver)
        }
        if let backgroundObserver = self.backgroundObserver {
            nc.removeObserver(backgroundObserver)
        }
    }
    
    // MARK: - setup
    private func setupSubviews() {
        emptySearchStateLabel.addCenteredTo(parentView: view)
    }

    // MARK: - configuration
    private func configureTableView() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: chatCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: deadDropCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        tableView.rowHeight = ContactCell.cellHeight
    }

    
    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            startTimer()
            viewModel.refreshData()
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
        viewModel.refreshData()
        updateTitle()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            tableView.rowHeight = ContactCell.cellHeight
        }
    }
    private func quitSearch(animated: Bool) {
        searchController.searchBar.text = nil
        self.viewModel.endSearch()
        searchController.dismiss(animated: animated) {
            self.tableView.scrollToTop()
        }
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource

    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsIn(section: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)

        switch cellData.type {
        case .deaddrop:
            guard let deaddropCell = tableView.dequeueReusableCell(withIdentifier: deadDropCellReuseIdentifier, for: indexPath) as? ContactCell else {
                break
            }
            deaddropCell.updateCell(cellViewModel: cellData)
            return deaddropCell
        case .chat(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_ARCHIVED_LINK {
                archiveCell.actionTitle = dcContext.getChat(chatId: chatId).name
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
        return viewModel.titleForHeaderIn(section: section)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)
        switch cellData.type {
        case .deaddrop(let deaddropData):
            safe_assert(deaddropData.chatId == DC_CHAT_ID_DEADDROP)
            showDeaddropRequestAlert(msgId: deaddropData.msgId)
        case .chat(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_ARCHIVED_LINK {
                showArchive()
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

        guard let chatId = viewModel.chatIdFor(section: indexPath.section, row: indexPath.row) else {
            return []
        }

        if chatId==DC_CHAT_ID_ARCHIVED_LINK || chatId==DC_CHAT_ID_DEADDROP {
            return []
            // returning nil may result in a default delete action,
            // see https://forums.developer.apple.com/thread/115030
        }
        let chat = dcContext.getChat(chatId: chatId)
        let archived = chat.isArchived
        let archiveActionTitle: String = String.localized(archived ? "unarchive" : "archive")

        let archiveAction = UITableViewRowAction(style: .destructive, title: archiveActionTitle) { [weak self] _, _ in
            self?.viewModel.archiveChatToggle(chatId: chatId)
        }
        archiveAction.backgroundColor = UIColor.lightGray

        let pinned = chat.visibility==DC_CHAT_VISIBILITY_PINNED
        let pinAction = UITableViewRowAction(style: .destructive, title: String.localized(pinned ? "unpin" : "pin")) { [weak self] _, _ in
            self?.viewModel.pinChatToggle(chatId: chat.id)
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
        if RelayHelper.sharedInstance.isForwarding() {
            title = String.localized("forward_to")
            if !viewModel.isArchive {
                navigationItem.setLeftBarButton(cancelButton, animated: true)
            }
        } else {
            title = viewModel.isArchive ? String.localized("chat_archived_chats_title") :
                String.localized("pref_chats")
            navigationItem.setLeftBarButton(nil, animated: true)
        }
    }

    func handleChatListUpdate() {
        tableView.reloadData()

        if let emptySearchText = viewModel.emptySearchText {
            let text = String.localizedStringWithFormat(
                String.localized("search_no_result_for_x"),
                emptySearchText
            )
            emptySearchStateLabel.text = text
            emptySearchStateLabel.isHidden = false
        } else {
            emptySearchStateLabel.text = nil
            emptySearchStateLabel.isHidden = true
        }
    }
    
    private func startTimer() {
        // check if the timer is not yet started
        if !(timer?.isValid ?? false) {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.viewModel.refreshData()
                }
            }
        }
    }
    
    private func stopTimer() {
        // check if the timer is not already stopped
        if timer?.isValid ?? false {
            timer?.invalidate()
        }
    }

    // MARK: - alerts
    private func showDeleteChatConfirmationAlert(chatId: Int) {
        let alert = UIAlertController(
            title: nil,
            message: String.localized("ask_delete_chat_desktop"),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.deleteChat(chatId: chatId, animated: true)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showDeaddropRequestAlert(msgId: Int) {
        let dcMsg = DcMsg(id: msgId)
        let (title, startButton, blockButton) = MailboxViewController.deaddropQuestion(context: dcContext, msg: dcMsg)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: startButton, style: .default, handler: { _ in
            let chat = self.dcContext.decideOnContactRequest(msgId, DC_DECISION_START_CHAT)
            self.showChat(chatId: chat.id)
        }))
        alert.addAction(UIAlertAction(title: String.localized("not_now"), style: .default, handler: { _ in
            DispatchQueue.global(qos: .background).async {
                self.dcContext.decideOnContactRequest(msgId, DC_DECISION_NOT_NOW)
            }
        }))
        alert.addAction(UIAlertAction(title: blockButton, style: .destructive, handler: { _ in
            DispatchQueue.global(qos: .background).async {
                self.dcContext.decideOnContactRequest(msgId, DC_DECISION_BLOCK)
            }
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func askToChatWith(contactId: Int) {
        let dcContact = DcContact(id: contactId)
        let alert = UIAlertController(
            title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr),
            message: nil,
            preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(
            title: String.localized("start_chat"),
            style: .default,
            handler: { _ in
                self.showNewChat(contactId: contactId)
        }))
        alert.addAction(UIAlertAction(
            title: String.localized("cancel"),
            style: .cancel,
            handler: { _ in
        }))
        self.present(alert, animated: true, completion: nil)
    }

    private func deleteChat(chatId: Int, animated: Bool) {
        if !animated {
            _ = viewModel.deleteChat(chatId: chatId)
            viewModel.refreshData()
            return
        }

        if viewModel.searchActive {
            _ = viewModel.deleteChat(chatId: chatId)
            viewModel.refreshData()
            viewModel.updateSearchResults(for: searchController)
            return
        }

        let row = viewModel.deleteChat(chatId: chatId)
        tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .fade)
    }

    // MARK: - coordinator
    private func showNewChatController() {
        let newChatVC = NewChatViewController(dcContext: dcContext)
        navigationController?.pushViewController(newChatVC, animated: true)
    }

    func showChat(chatId: Int, highlightedMsg: Int? = nil, animated: Bool = true) {
        //let chatVC = ChatViewController(dcContext: dcContext, chatId: chatId)
        let chatVC = ChatViewController(dcContext: dcContext, chatId: chatId, highlightedMsg: highlightedMsg)
        navigationController?.pushViewController(chatVC, animated: animated)
    }

    private func showArchive() {
        let viewModel = ChatListViewModel(dcContext: dcContext, isArchive: true)
        let controller = ChatListController(dcContext: dcContext, viewModel: viewModel)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        showChat(chatId: Int(chatId))
    }
}

// MARK: - uisearchbardelegate
extension ChatListController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        viewModel.beginSearch()
        return true
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // searchBar will be set to "" by system
        viewModel.endSearch()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
           self.tableView.scrollToTop()
        }
    }

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        tableView.scrollToTop()
        return true
    }
}
