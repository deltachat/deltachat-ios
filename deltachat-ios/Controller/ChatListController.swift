import UIKit

class ChatListController: UITableViewController {
    weak var coordinator: ChatListCoordinator?
    private let viewModel: ChatListViewModelProtocol

    private let chatCellReuseIdentifier = "ChatCell"
    private let archivedCellReuseIdentifier = "ArchiveCell"
    private let deadDropCellReuseIdentifier = "DeaddropCell"
    private let contactCellReuseIdentifier = "ContactCell"


    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = viewModel
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.searchBar.delegate = self
        return searchController
    }()

    private var msgChangedObserver: Any?
    private var incomingMsgObserver: Any?
    private var viewChatObserver: Any?

    private var newButton: UIBarButtonItem!

    lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    init(viewModel: ChatListViewModelProtocol) {
        self.viewModel = viewModel
        super.init(style: .grouped)
        viewModel.onChatListUpdate = {
            [unowned self] in
            self.tableView.reloadData()
        }
        configureTableView()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        newButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.compose, target: self, action: #selector(didPressNewChat))
        newButton.tintColor = DcColors.primary
        navigationItem.rightBarButtonItem = newButton
        navigationItem.searchController = searchController
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTitle()
        // reloading when search active caused a UI-glitch and is actually not needed as long swipe actions are
        if !viewModel.searchActive {
            tableView.reloadData()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(
            forName: dcNotificationChanged,
            object: nil, queue: nil) { _ in
                self.tableView.reloadData()
        }
        incomingMsgObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil, queue: nil) { _ in
                self.tableView.reloadData()
        }
        viewChatObserver = nc.addObserver(
        forName: dcNotificationViewChat, object: nil, queue: nil) { notification in
            if let chatId = notification.userInfo?["chat_id"] as? Int {
                self.coordinator?.showChat(chatId: chatId)
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
    }

    // MARK: setup
    private func configureTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: archivedCellReuseIdentifier)
        tableView.register(AvatarTextCell.self, forCellReuseIdentifier: chatCellReuseIdentifier)
        tableView.register(AvatarTextCell.self, forCellReuseIdentifier: deadDropCellReuseIdentifier)
        tableView.register(AvatarTextCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        tableView.rowHeight = 80
    }

    // MARK: actions
    @objc func didPressNewChat() {
        coordinator?.showNewChatController()
    }

    @objc func cancelButtonPressed() {
        RelayHelper.sharedInstance.cancel()
        updateTitle()
    }

    private func updateTitle() {
        if RelayHelper.sharedInstance.isForwarding() {
            title = String.localized("forward_to")
            if viewModel.showArchive {
                navigationItem.setLeftBarButton(cancelButton, animated: true)
            }
        } else {
            title = viewModel.showArchive ? String.localized("chat_archived_chats_title") :
                String.localized("pref_chats")
            navigationItem.setLeftBarButton(nil, animated: true)
        }
    }


// MARK: uiTableViewDatasource, uiTabelViewDelegate

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.titleForHeaderIn(section: section)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
          return viewModel.numberOfRowsIn(section: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cellViewModel = viewModel.getCellViewModelFor(indexPath: indexPath)

        switch cellViewModel.type {
        case .CHAT(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_ARCHIVED_LINK {
                let archiveCell = tableView.dequeueReusableCell(withIdentifier: archivedCellReuseIdentifier, for: indexPath)
                update(archiveCell: archiveCell)
                return archiveCell
            }

            if chatId == DC_CHAT_ID_DEADDROP, let msgId = viewModel.msgIdFor(indexPath: indexPath) {
                let deaddropCell = tableView.dequeueReusableCell(withIdentifier: deadDropCellReuseIdentifier, for: indexPath) as! AvatarTextCell
                update(deaddropCell: deaddropCell, msgId: msgId)
                return deaddropCell
            }

            // default chatCells
            let chatCell = tableView.dequeueReusableCell(withIdentifier: chatCellReuseIdentifier, for: indexPath) as! AvatarTextCell
            let cellViewModel = viewModel.getCellViewModelFor(indexPath: indexPath)
            update(avatarCell: chatCell, cellViewModel: cellViewModel)
            return chatCell
        case .CONTACT(let contactData):
            // will be shown when search is active
            let contactCell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as! AvatarTextCell
            update(avatarCell: contactCell, cellViewModel: cellViewModel)
            return contactCell
        }
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellViewModel = viewModel.getCellViewModelFor(indexPath: indexPath)
        switch cellViewModel.type {
        case .CHAT(let chatData):
            let chatId = chatData.chatId
            if chatId == DC_CHAT_ID_DEADDROP {
                guard let msgId = viewModel.msgIdFor(indexPath: indexPath) else {
                    return
                }
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
        case .CONTACT(let contactData):
            let contactId = contactData.contactId
            self.askToChatWith(contactId: contactId)
        }
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if viewModel.searchActive {
            // no actions when search active
            return []
        }

        guard let chatId = viewModel.chatIdFor(indexPath: indexPath) else {
            return []
        }

        if chatId==DC_CHAT_ID_ARCHIVED_LINK || chatId==DC_CHAT_ID_DEADDROP {
            return []
            // returning nil may result in a default delete action,
            // see https://forums.developer.apple.com/thread/115030
        }

        var title = String.localized("archive")
        if viewModel.showArchive {
            title = String.localized("unarchive")
        }
        let archive = UITableViewRowAction(style: .destructive, title: title) { [unowned self] _, _ in
            self.viewModel.archieveChat(chatId: chatId)
        }
        archive.backgroundColor = UIColor.lightGray

        let delete = UITableViewRowAction(style: .destructive, title: String.localized("delete")) { [unowned self] _, _ in
            self.showDeleteChatConfirmationAlert(chatId: chatId)
        }
        delete.backgroundColor = UIColor.red

        return [archive, delete]
    }

    // MARK: cell updates

    private func update(deaddropCell: AvatarTextCell, msgId: Int) {
        deaddropCell.backgroundColor = DcColors.deaddropBackground
        deaddropCell.contentView.backgroundColor = DcColors.deaddropBackground

        let contact = DcContact(id: DcMsg(id: msgId).fromContactId)
        if let img = contact.profileImage {
            deaddropCell.resetBackupImage()
            deaddropCell.setImage(img)
        } else {
            deaddropCell.setBackupImage(name: contact.name, color: contact.color)
        }
    }

    private func update(archiveCell: UITableViewCell) {
        archiveCell.textLabel?.textAlignment = .center
        var title = String.localized("chat_archived_chats_title")
        let count = viewModel.archivedChatsCount
        title.append(" (\(count))")
        archiveCell.textLabel?.text = title
        archiveCell.textLabel?.textColor = .systemBlue
    }

    private func update(avatarCell cell: AvatarTextCell, cellViewModel: AvatarCellViewModel) {
        cell.updateCell(cellViewModel: cellViewModel)
    }

    private func showDeleteChatConfirmationAlert(chatId: Int) {
        let alert = UIAlertController(
            title: nil,
            message: String.localized("ask_delete_chat_desktop"),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.viewModel.deleteChat(chatId: chatId)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
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
