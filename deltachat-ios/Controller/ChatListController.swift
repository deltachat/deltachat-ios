import UIKit

class ChatListController: UITableViewController {
    weak var coordinator: ChatListCoordinator?
    let viewModel: ChatListViewModelProtocol

    private let chatCellReuseIdentifier = "chat_cell"
    private let deadDropCellReuseIdentifier = "deaddrop_cell"
    private let contactCellReuseIdentifier = "contact_cell"

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.searchBar.delegate = self
        return searchController
    }()

    private var dcContext: DcContext
    private var chatList: DcChatlist?
    private let showArchive: Bool

    private var msgChangedObserver: Any?
    private var incomingMsgObserver: Any?
    private var viewChatObserver: Any?
    private var deleteChatObserver: Any?

    private lazy var newButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.compose, target: self, action: #selector(didPressNewChat))
        button.tintColor = DcColors.primary
        return button
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    private lazy var archiveCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.textLabel?.textColor = .systemBlue
        return cell
    }()

    init(viewModel: ChatListViewModelProtocol, dcContext: DcContext, showArchive: Bool) {
        self.dcContext = dcContext
        self.viewModel = viewModel
        self.showArchive = showArchive
        dcContext.updateDeviceChats()
        super.init(nibName: nil, bundle: nil)
        viewModel.onChatListUpdate = handleChatListUpdate
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
         super.viewDidLoad()
         navigationItem.rightBarButtonItem = newButton
         configureTableView()
     }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getChatList()

        if RelayHelper.sharedInstance.isForwarding() {
            chatTable.scrollToTop()
        }

        updateTitle()

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

    // Mark: - configuration
    private func configureTableView() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: chatCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: deadDropCellReuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        tableView.rowHeight = 80
    }

    @objc func didPressNewChat() {
        coordinator?.showNewChatController()
    }

    @objc func cancelButtonPressed() {
        // cancel forwarding
        RelayHelper.sharedInstance.cancel()
        getChatList()
        updateTitle()
    }

    private func getChatList() {
        var gclFlags: Int32 = 0
        if showArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        } else if RelayHelper.sharedInstance.isForwarding() {
            gclFlags |= DC_GCL_FOR_FORWARDING
        }
        chatList = dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
        tableView.reloadData()
    }

    private func updateTitle() {
        if RelayHelper.sharedInstance.isForwarding() {
            title = String.localized("forward_to")
            if !showArchive {
                navigationItem.setLeftBarButton(cancelButton, animated: true)
            }
        } else {
            title = showArchive ? String.localized("chat_archived_chats_title") :
                String.localized("pref_chats")
            navigationItem.setLeftBarButton(nil, animated: true)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    return viewModel.numberOfRowsIn(section: section)
    }

override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

    let cellData = viewModel.cellDataFor(section: indexPath.section, row: indexPath.row)

    switch cellData.type {
    case .CHAT(let chatData):
        let chatId = chatData.chatId
        if chatId == DC_CHAT_ID_ARCHIVED_LINK {
            updateArchivedCell() // to make sure archived chats count is always right
            return archiveCell
        } else if chatId == DC_CHAT_ID_DEADDROP, let deaddropCell = tableView.dequeueReusableCell(withIdentifier: deadDropCellReuseIdentifier, for: indexPath) as? ContactCell {
            // TODO update
            return deaddropCell
        } else if let chatCell = tableView.dequeueReusableCell(withIdentifier: chatCellReuseIdentifier, for: indexPath) as? ContactCell {
        // default chatCell
            chatCell.updateCell(cellViewModel: cellData)
            return chatCell
        }
    case .CONTACT:
        safe_assert(viewModel.searchActive)
        if let contactCell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ContactCell {
            contactCell.updateCell(cellViewModel: cellData)
            return contactCell
        }
    }
    safe_fatalError("Could not find/dequeue or recycle UITableViewCell.")
    return UITableViewCell()


    /*
        let row = indexPath.row
        guard let chatList = self.chatList else {
            fatalError("chatList was nil in data source")
        }

        let chatId = chatList.getChatId(index: row)
        let chat = DcChat(id: chatId)
        if chatId == DC_CHAT_ID_ARCHIVED_LINK {
            return getArchiveCell(tableView, title: chat.name)
        }

        let cell: ContactCell
        if chatId == DC_CHAT_ID_DEADDROP {
            cell = getDeaddropCell(tableView)
        } else if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as? ContactCell {
            cell = c
        } else {
            cell = ContactCell(style: .default, reuseIdentifier: "ChatCell")
        }

        let summary = chatList.getSummary(index: row)
        let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)

        cell.titleLabel.attributedText = (unreadMessages > 0) ?
            NSAttributedString(string: chat.name, attributes: [ .font: UIFont.systemFont(ofSize: 16, weight: .bold) ]) :
            NSAttributedString(string: chat.name, attributes: [ .font: UIFont.systemFont(ofSize: 16, weight: .medium) ])

        if chatId == DC_CHAT_ID_DEADDROP {
            let contact = DcContact(id: DcMsg(id: chatList.getMsgId(index: row)).fromContactId)
            if let img = contact.profileImage {
                cell.resetBackupImage()
                cell.setImage(img)
            } else {
                cell.setBackupImage(name: contact.name, color: contact.color)
            }
        } else {
            if let img = chat.profileImage {
                cell.resetBackupImage()
                cell.setImage(img)
            } else {
                cell.setBackupImage(name: chat.name, color: chat.color)
            }

            if chat.visibility == DC_CHAT_VISIBILITY_PINNED {
                cell.backgroundColor = DcColors.deaddropBackground
                cell.contentView.backgroundColor = DcColors.deaddropBackground
            } else {
                cell.backgroundColor = DcColors.contactCellBackgroundColor
                cell.contentView.backgroundColor = DcColors.contactCellBackgroundColor
            }
        }

        cell.setVerified(isVerified: chat.isVerified)

        let result1 = summary.text1 ?? ""
        let result2 = summary.text2 ?? ""
        let result: String
        if !result1.isEmpty, !result2.isEmpty {
            result = "\(result1): \(result2)"
        } else {
            result = "\(result1)\(result2)"
        }

        cell.subtitleLabel.text = result
        cell.setTimeLabel(summary.timestamp)
        cell.setStatusIndicators(unreadCount: unreadMessages, status: summary.state, visibility: chat.visibility, isLocationStreaming: chat.isSendingLocations)
        return cell
    */
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        guard let chatList = chatList else { return }
        let chatId = chatList.getChatId(index: row)
        if chatId == DC_CHAT_ID_DEADDROP {
            let msgId = chatList.getMsgId(index: row)
            let dcMsg = DcMsg(id: msgId)
            let dcContact = DcContact(id: dcMsg.fromContactId)
            let title = String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr)
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                let chat = dcMsg.createChat()
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
        } else if chatId == DC_CHAT_ID_ARCHIVED_LINK {
            coordinator?.showArchive()
        } else {
            coordinator?.showChat(chatId: chatId)
        }
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let row = indexPath.row
        guard let chatList = chatList else {
            return []
        }

        let chatId = chatList.getChatId(index: row)
        if chatId==DC_CHAT_ID_ARCHIVED_LINK || chatId==DC_CHAT_ID_DEADDROP {
            return []
            // returning nil may result in a default delete action,
            // see https://forums.developer.apple.com/thread/115030
        }

        let archive = UITableViewRowAction(style: .destructive, title: String.localized(showArchive ? "unarchive" : "archive")) { [unowned self] _, _ in
            self.dcContext.archiveChat(chatId: chatId, archive: !self.showArchive)
        }
        archive.backgroundColor = UIColor.lightGray

        let chat = dcContext.getChat(chatId: chatId)
        let pinned = chat.visibility==DC_CHAT_VISIBILITY_PINNED
        let pin = UITableViewRowAction(style: .destructive, title: String.localized(pinned ? "unpin" : "pin")) { [unowned self] _, _ in
            self.dcContext.setChatVisibility(chatId: chatId, visibility: pinned ? DC_CHAT_VISIBILITY_NORMAL : DC_CHAT_VISIBILITY_PINNED)
        }
        pin.backgroundColor = UIColor.systemGreen

        let delete = UITableViewRowAction(style: .normal, title: String.localized("delete")) { [unowned self] _, _ in
            self.showDeleteChatConfirmationAlert(chatId: chatId)
        }
        delete.backgroundColor = UIColor.systemRed

        return [archive, pin, delete]
    }

    // MARK: updates

    func handleChatListUpdate() {
        tableView.reloadData()
    }

    func updateArchivedCell() {
        var title = String.localized("chat_archived_chats_title")
        let count = viewModel.numberOfArchivedChats
        title.append(" (\(count))")
        archiveCell.textLabel?.text = title
    }

    func getDeaddropCell(_ tableView: UITableView) -> ContactCell {
        let deaddropCell: ContactCell
        if let cell = tableView.dequeueReusableCell(withIdentifier: "DeaddropCell") as? ContactCell {
            deaddropCell = cell
        } else {
            deaddropCell = ContactCell(style: .default, reuseIdentifier: "DeaddropCell")
        }
        deaddropCell.backgroundColor = DcColors.deaddropBackground
        deaddropCell.contentView.backgroundColor = DcColors.deaddropBackground
        return deaddropCell
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

    private func deleteChat(chatId: Int, animated: Bool) {

        if !animated {
            dcContext.deleteChat(chatId: chatId)
            self.getChatList()
            return
        }

        guard let chatList = chatList else {
            return
        }

        // find index of chatId
        let indexToDelete = Array(0..<chatList.length).filter { chatList.getChatId(index: $0) == chatId }.first

        guard let row = indexToDelete else {
            return
        }

        var gclFlags: Int32 = 0
        if showArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        }

        dcContext.deleteChat(chatId: chatId)
        self.chatList = dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
        tableView.deleteRows(at: [IndexPath(row: row, section: 0)], with: .fade)
    }
}

extension ChatListController: UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        viewModel.beginFiltering()
        return true
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        viewModel.endFiltering()
    }
}
