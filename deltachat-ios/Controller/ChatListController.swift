import UIKit
import DcCore

class ChatListController: UITableViewController {
    weak var coordinator: ChatListCoordinator?
    let viewModel: ChatListViewModelProtocol
    let dcContext: DcContext

    private let chatCellReuseIdentifier = "chat_cell"
    private let deadDropCellReuseIdentifier = "deaddrop_cell"
    private let contactCellReuseIdentifier = "contact_cell"

    private var msgChangedObserver: Any?
    private var incomingMsgObserver: Any?
    private var viewChatObserver: Any?
    private var deleteChatObserver: Any?

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.searchBar.delegate = self
        return searchController
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

    func getArchiveCell(title: String) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.textLabel?.textColor = .systemBlue
        cell.textLabel?.text = title
        cell.textLabel?.textAlignment = .center
        return cell
    }

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        dcContext.updateDeviceChats()
        updateTitle()
        viewModel.refreshData()

        if RelayHelper.sharedInstance.isForwarding() {
            quitSearch(animated: false)
            tableView.scrollToTop()
        }

        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil,
            queue: nil) { _ in
                self.viewModel.refreshData()

        }
        incomingMsgObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil,
            queue: nil) { _ in
                self.viewModel.refreshData()
        }
        viewChatObserver = nc.addObserver(
            forName: dcNotificationViewChat,
            object: nil,
            queue: nil) { notification in
                if let chatId = notification.userInfo?["chat_id"] as? Int {
                    self.coordinator?.showChat(chatId: chatId)
                }
        }
        deleteChatObserver = nc.addObserver(
            forName: dcNotificationChatDeletedInChatDetail,
            object: nil,
            queue: nil) { notification in
                if let chatId = notification.userInfo?["chat_id"] as? Int {
                    self.deleteChat(chatId: chatId, animated: true)
                }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

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

        if let deleteChatObserver = self.deleteChatObserver {
            nc.removeObserver(deleteChatObserver)
        }
    }

    // MARK: - configuration
    private func configureTableView() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: chatCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: deadDropCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        tableView.rowHeight = 80
    }

    // MARK: - actions
    @objc func didPressNewChat() {
        coordinator?.showNewChatController()
    }

    @objc func cancelButtonPressed() {
        // cancel forwarding
        RelayHelper.sharedInstance.cancel()
        viewModel.refreshData()
        updateTitle()
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
                return getArchiveCell(title: dcContext.getChat(chatId: chatId).name)
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
        }
        safe_fatalError("Could not find/dequeue or recycle UITableViewCell.")
        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.titleForHeaderIn(section: section)
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)
        switch cellData.type {
        case .deaddrop(let deaddropData):
            safe_assert(deaddropData.chatId == DC_CHAT_ID_DEADDROP)
            showDeaddropRequestAlert(msgId: deaddropData.msgId)
        case .chat(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_ARCHIVED_LINK {
                coordinator?.showArchive()
            } else {
                coordinator?.showChat(chatId: chatId)
            }
        case .contact(let contactData):
            let contactId = contactData.contactId
            if let chatId = contactData.chatId {
                coordinator?.showChat(chatId: chatId)
            } else {
                self.askToChatWith(contactId: contactId)
            }
        }
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {

        if viewModel.searchActive {
            // no swipe actions during search
            return []
        }

        guard let chatId = viewModel.chatIdFor(section: indexPath.section, row: indexPath.row) else {
            return []
        }

        if chatId==DC_CHAT_ID_ARCHIVED_LINK || chatId==DC_CHAT_ID_DEADDROP {
            return []
            // returning nil may result in a default delete action,
            // see https://forums.developer.apple.com/thread/115030
        }
        let archiveActionTitle: String = String.localized(viewModel.isArchive ? "unarchive" : "archive")

        let archiveAction = UITableViewRowAction(style: .destructive, title: archiveActionTitle) { [unowned self] _, _ in
            self.viewModel.archiveChatToggle(chatId: chatId)
        }
        archiveAction.backgroundColor = UIColor.lightGray

        let chat = dcContext.getChat(chatId: chatId)
        let pinned = chat.visibility==DC_CHAT_VISIBILITY_PINNED
        let pinAction = UITableViewRowAction(style: .destructive, title: String.localized(pinned ? "unpin" : "pin")) { [unowned self] _, _ in
            self.viewModel.pinChatToggle(chatId: chat.id)
        }
        pinAction.backgroundColor = UIColor.systemGreen

        let deleteAction = UITableViewRowAction(style: .normal, title: String.localized("delete")) { [unowned self] _, _ in
            self.showDeleteChatConfirmationAlert(chatId: chatId)
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
    }

    func getArchiveCell(_ tableView: UITableView, title: String) -> UITableViewCell {
        let archiveCell: UITableViewCell
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ArchiveCell") {
            archiveCell = cell
        } else {
            archiveCell = UITableViewCell(style: .default, reuseIdentifier: "ArchiveCell")
        }
        archiveCell.textLabel?.textAlignment = .center
        archiveCell.textLabel?.text = title
        archiveCell.textLabel?.textColor = .systemBlue
        return archiveCell
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
        let dcContact = DcContact(id: dcMsg.fromContactId)
        let title = String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
            let chat = self.dcContext.createChatByMessageId(msgId)
            self.coordinator?.showChat(chatId: chat.id)
        }))
        alert.addAction(UIAlertAction(title: String.localized("not_now"), style: .default, handler: { _ in
            dcContact.marknoticed()
        }))
        alert.addAction(UIAlertAction(title: String.localized("menu_block_contact"), style: .destructive, handler: { _ in
            dcContact.block()
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
                self.coordinator?.showNewChat(contactId: contactId)
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

        let row = viewModel.deleteChat(chatId: chatId)
        tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .fade)
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
