import UIKit

class ChatListController: UIViewController {
    weak var coordinator: ChatListCoordinator?

    private var dcContext: DcContext
    private var chatList: DcChatlist?

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

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.largeTitleDisplayMode = .always
        }
        getChatList()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
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
        title = String.localized("pref_chats")
        navigationController?.navigationBar.prefersLargeTitles = true

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

    private func getChatList() {
        guard let chatlistPointer = dc_get_chatlist(mailboxPointer, 0, nil, 0) else {
            fatalError("chatlistPointer was nil")
        }
        // ownership of chatlistPointer transferred here to ChatList object
        chatList = DcChatlist(chatListPointer: chatlistPointer)
        chatTable.reloadData()
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

        let cell: ContactCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as? ContactCell {
            cell = c
        } else {
            cell = ContactCell(style: .default, reuseIdentifier: "ChatCell")
        }

        let chatId = chatList.getChatId(index: row)
        let chat = DcChat(id: chatId)
        let summary = chatList.getSummary(index: row)

        cell.nameLabel.text = chat.name
        if let img = chat.profileImage {
            cell.setImage(img)
        } else {
            cell.setBackupImage(name: chat.name, color: chat.color)
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
        cell.setDeliveryStatusIndicator(summary.state)

        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if let chatId = chatList?.getChatId(index: row) {
            coordinator?.showChat(chatId: chatId)
        }
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let row = indexPath.row
        guard let chatList = chatList else {
            return []
        }

        let chatId = chatList.getChatId(index: row)
        if chatId==DC_CHAT_ID_ARCHIVED_LINK {
            return []
            // returning nil may result in a default delete action,
            // see https://forums.developer.apple.com/thread/115030
        }

        let archive = UITableViewRowAction(style: .destructive, title: String.localized("menu_archive_chat")) { [unowned self] _, _ in
            self.dcContext.archiveChat(chatId: chatId, archive: true)
        }
        archive.backgroundColor = UIColor.gray

        let delete = UITableViewRowAction(style: .destructive, title: String.localized("menu_delete_chat")) { [unowned self] _, _ in
            self.showDeleteChatConfirmationAlert(chatId: chatId)
        }
        delete.backgroundColor = UIColor.red

        return [archive, delete]
    }
}

extension ChatListController {
    private func showDeleteChatConfirmationAlert(chatId: Int) {
        let alert = UIAlertController(
            title: String.localized("ask_delete_chat_desktop"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String.localized("global_menu_edit_delete_desktop"), style: .default, handler: { _ in
            self.deleteChat(chatId: chatId)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func deleteChat(chatId: Int) {
        dc_delete_chat(mailboxPointer, UInt32(chatId))
        self.getChatList()
    }

}
