import UIKit

class ChatListController: UIViewController {
    weak var coordinator: ChatListCoordinator?

    private var dcContext: DcContext
    private var chatList: DcChatlist?
    private var showArchive: Bool

    private lazy var chatTable: UITableView = {
        let chatTable = UITableView()
        chatTable.dataSource = self
        chatTable.delegate = self
        chatTable.rowHeight = 80
        return chatTable
    }()

    private var msgChangedObserver: Any?
    private var incomingMsgObserver: Any?
    private var viewChatObserver: Any?

    private var newButton: UIBarButtonItem!

    lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    init(dcContext: DcContext, showArchive: Bool) {
        self.dcContext = dcContext
        self.showArchive = showArchive
        dcContext.updateDeviceChats()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getChatList()
        updateTitle()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(forName: dcNotificationChanged,
                                            object: nil, queue: nil) { _ in
            self.getChatList()
        }
        incomingMsgObserver = nc.addObserver(forName: dcNotificationIncoming,
                                             object: nil, queue: nil) { _ in
            self.getChatList()
        }

        viewChatObserver = nc.addObserver(forName: dcNotificationViewChat, object: nil, queue: nil) { notification in
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

    override func viewDidLoad() {
        super.viewDidLoad()

        newButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.compose, target: self, action: #selector(didPressNewChat))
        newButton.tintColor = DcColors.primary
        navigationItem.rightBarButtonItem = newButton

        setupChatTable()
    }

    private func setupChatTable() {
        view.addSubview(chatTable)
        chatTable.translatesAutoresizingMaskIntoConstraints = false
        chatTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        chatTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        chatTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        chatTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }

    @objc func didPressNewChat() {
        coordinator?.showNewChatController()
    }

    @objc func cancelButtonPressed() {
        RelayHelper.sharedInstance.cancel()
        updateTitle()
    }

    private func getNumberOfArchivedChats() -> Int {
        let chatList = dcContext.getChatlist(flags: DC_GCL_ARCHIVED_ONLY, queryString: nil, queryId: 0)
        return chatList.length
    }

    private func getChatList() {
        var gclFlags: Int32 = 0
        if showArchive {
            gclFlags |= DC_GCL_ARCHIVED_ONLY
        }
        chatList = dcContext.getChatlist(flags: gclFlags, queryString: nil, queryId: 0)
        chatTable.reloadData()
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
}

extension ChatListController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        guard let chatList = self.chatList else {
            fatalError("chatList was nil in data source")
        }

        return chatList.length
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        guard let chatList = self.chatList else {
            fatalError("chatList was nil in data source")
        }

        let chatId = chatList.getChatId(index: row)
        if chatId == DC_CHAT_ID_ARCHIVED_LINK {
            return getArchiveCell(tableView)
        }

        let cell: ContactCell
        if chatId == DC_CHAT_ID_DEADDROP {
            cell = getDeaddropCell(tableView)
        } else if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as? ContactCell {
            cell = c
        } else {
            cell = ContactCell(style: .default, reuseIdentifier: "ChatCell")
        }

        let chat = DcChat(id: chatId)
        let summary = chatList.getSummary(index: row)
        let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)

        cell.nameLabel.attributedText = (unreadMessages > 0) ?
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

        cell.emailLabel.text = result
        cell.setTimeLabel(summary.timestamp)
        cell.setUnreadMessageCounter(unreadMessages)
        cell.setDeliveryStatusIndicator(summary.state)

        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        guard let chatList = chatList else { return }
        let chatId = chatList.getChatId(index: row)
        if chatId == DC_CHAT_ID_DEADDROP {
            let msgId = chatList.getMsgId(index: row)
            let dcMsg = DcMsg(id: msgId)
            let dcContact = DcContact(id: dcMsg.fromContactId)
            let title = String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr)
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
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

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
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

        var title = String.localized("archive")
        if showArchive {
            title = String.localized("unarchive")
        }
        let archive = UITableViewRowAction(style: .destructive, title: title) { [unowned self] _, _ in
            self.dcContext.archiveChat(chatId: chatId, archive: !self.showArchive)
        }
        archive.backgroundColor = UIColor.lightGray

        let delete = UITableViewRowAction(style: .destructive, title: String.localized("delete")) { [unowned self] _, _ in
            self.showDeleteChatConfirmationAlert(chatId: chatId)
        }
        delete.backgroundColor = UIColor.red

        return [archive, delete]
    }

    func getDeaddropCell(_ tableView: UITableView) -> ContactCell {
        let deaddropCell: ContactCell
        if let cell = tableView.dequeueReusableCell(withIdentifier: "DeaddropCell") as? ContactCell {
            deaddropCell = cell
        } else {
            deaddropCell = ContactCell(style: .default, reuseIdentifier: "DeaddropCell")
        }
        deaddropCell.backgroundColor = DcColors.deaddropBackground // TODO: why is the color not changed in darkmode?
        return deaddropCell
    }

    func getArchiveCell(_ tableView: UITableView) -> UITableViewCell {
        let archiveCell: UITableViewCell
        if let cell = tableView.dequeueReusableCell(withIdentifier: "ArchiveCell") {
            archiveCell = cell
        } else {
            archiveCell = UITableViewCell(style: .default, reuseIdentifier: "ArchiveCell")
        }
        archiveCell.textLabel?.textAlignment = .center
        var title = String.localized("chat_archived_chats_title")
        let count = getNumberOfArchivedChats()
        title.append(" (\(count))")
        archiveCell.textLabel?.text = title
        archiveCell.textLabel?.textColor = .systemBlue
        return archiveCell
    }

    private func showDeleteChatConfirmationAlert(chatId: Int) {
        let alert = UIAlertController(
            title: nil,
            message: String.localized("ask_delete_chat_desktop"),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.dcContext.deleteChat(chatId: chatId)
            self.getChatList()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
