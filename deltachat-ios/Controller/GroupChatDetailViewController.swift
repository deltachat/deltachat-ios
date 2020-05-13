import UIKit
import DcCore

class GroupChatDetailViewController: UIViewController {

    enum ProfileSections {
        case attachments
        case members
        case chatActions
    }

    private let attachmentsRowGallery = 0
    private let attachmentsRowDocuments = 1
    private let membersRowAddMembers = 0
    private let membersRowQrInvite = 1
    private let memberManagementRows = 2
    private let chatActionsRowArchiveChat = 0
    private let chatActionsRowLeaveGroup = 1
    private let chatActionsRowDeleteChat = 2

    private let dcContext: DcContext

    private let sections: [ProfileSections] = [.attachments, .members, .chatActions]

    private var currentUser: DcContact? {
        let myId = groupMemberIds.filter { DcContact(id: $0).email == dcContext.addr }.first
        guard let currentUserId = myId else {
            return nil
        }
        return DcContact(id: currentUserId)
    }

    private var chatId: Int
    fileprivate var chat: DcChat

    // stores contactIds
    private var groupMemberIds: [Int] = []

    // MARK: - subviews

    private lazy var editBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: String.localized("global_menu_edit_desktop"), style: .plain, target: self, action: #selector(editButtonPressed))
    }()

    lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.register(UITableViewCell.self, forCellReuseIdentifier: "tableCell")
        table.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
        table.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        table.delegate = self
        table.dataSource = self
        table.tableHeaderView = groupHeader
        return table
    }()

    private lazy var groupHeader: ContactDetailHeader = {
        let header = ContactDetailHeader()
        header.updateDetails(
            title: chat.name,
            subtitle: String.localizedStringWithFormat(String.localized("n_members"), chat.contactIds.count)
        )
        if let img = chat.profileImage {
            header.setImage(img)
        } else {
            header.setBackupImage(name: chat.name, color: chat.color)
        }
        header.setVerified(isVerified: chat.isVerified)
        return header
    }()

    private lazy var archiveChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = chat.isArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        cell.actionColor = UIColor.systemBlue
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var leaveGroupCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_leave_group")
        cell.actionColor = UIColor.red
        return cell
    }()


    private lazy var deleteChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_delete_chat")
        cell.actionColor = UIColor.red
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var galleryCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("gallery")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var documentsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("documents")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    init(chatId: Int, dcContext: DcContext) {
        self.dcContext = dcContext
        self.chatId = chatId
        chat = dcContext.getChat(chatId: chatId)
        super.init(nibName: nil, bundle: nil)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("tab_group")
        navigationItem.rightBarButtonItem = editBarButtonItem
        groupHeader.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //update chat object, maybe chat name was edited
        chat = dcContext.getChat(chatId: chat.id)
        updateGroupMembers()
        tableView.reloadData() // to display updates
        editBarButtonItem.isEnabled = currentUser != nil
        updateHeader()
    }

    // MARK: - update
    private func updateGroupMembers() {
        groupMemberIds = chat.contactIds
        tableView.reloadData()
    }

    private func updateHeader() {
        groupHeader.updateDetails(
            title: chat.name,
            subtitle: String.localizedStringWithFormat(String.localized("n_members"), chat.contactIds.count)
        )
        if let img = chat.profileImage {
            groupHeader.setImage(img)
        } else {
            groupHeader.setBackupImage(name: chat.name, color: chat.color)
        }
        groupHeader.setVerified(isVerified: chat.isVerified)
    }

    // MARK: - actions
    @objc func editButtonPressed() {
        showGroupChatEdit(chat: chat)
    }

    private func toggleArchiveChat() {
        let archivedBefore = chat.isArchived
        dcContext.archiveChat(chatId: chat.id, archive: !archivedBefore)
        if archivedBefore {
            archiveChatCell.actionTitle = String.localized("menu_archive_chat")
        } else {
            self.navigationController?.popToRootViewController(animated: false)
        }
        self.chat = dcContext.getChat(chatId: chat.id)
     }

    private func getGroupMemberIdFor(_ row: Int) -> Int {
        return groupMemberIds[row - memberManagementRows]
    }

    private func isMemberManagementRow(row: Int) -> Bool {
        return row < memberManagementRows
    }

    // MARK: - coordinator
    private func showSingleChatEdit(contactId: Int) {
        let editContactController = EditContactController(dcContext: dcContext, contactIdForUpdate: contactId)
        navigationController?.pushViewController(editContactController, animated: true)
    }

    private func showAddGroupMember(chatId: Int) {
        let groupMemberViewController = AddGroupMembersViewController(chatId: chatId)
        navigationController?.pushViewController(groupMemberViewController, animated: true)
    }

    private func showQrCodeInvite(chatId: Int) {
        let qrInviteCodeController = QrInviteViewController(dcContext: dcContext, chatId: chatId)
        navigationController?.pushViewController(qrInviteCodeController, animated: true)
    }

    private func showGroupChatEdit(chat: DcChat) {
        let editGroupViewController = EditGroupViewController(dcContext: dcContext, chat: chat)
        navigationController?.pushViewController(editGroupViewController, animated: true)
    }

    private func showContactDetail(of contactId: Int) {
        let viewModel = ContactDetailViewModel(contactId: contactId, chatId: nil, context: dcContext)
        let contactDetailController = ContactDetailViewController(viewModel: viewModel)
        navigationController?.pushViewController(contactDetailController, animated: true)
    }

    private func showDocuments() {
        presentPreview(for: DC_MSG_FILE, messageType2: DC_MSG_AUDIO, messageType3: 0)
    }

    private func showGallery() {
        presentPreview(for: DC_MSG_IMAGE, messageType2: DC_MSG_GIF, messageType3: DC_MSG_VIDEO)
    }

    private func presentPreview(for messageType: Int32, messageType2: Int32, messageType3: Int32) {
        let messageIds = dcContext.getChatMedia(chatId: chatId, messageType: messageType, messageType2: messageType2, messageType3: messageType3)
        var mediaUrls: [URL] = []
        for messageId in messageIds {
            let message = DcMsg.init(id: messageId)
            if let url = message.fileURL {
                mediaUrls.insert(url, at: 0)
            }
        }
        let previewController = PreviewController(currentIndex: 0, urls: mediaUrls)
        navigationController?.pushViewController(previewController, animated: true)
    }

    private func deleteChat() {
        dcContext.deleteChat(chatId: chatId)

        // just pop to viewControllers - we've in chatlist or archive then
        // (no not use `navigationController?` here: popping self will make the reference becoming nil)
        if let navigationController = navigationController {
            navigationController.popViewController(animated: false)
            navigationController.popViewController(animated: true)
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension GroupChatDetailViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionType = sections[section]
        switch sectionType {
        case .attachments:
            return 2
        case .members:
            return groupMemberIds.count + memberManagementRows
        case .chatActions:
            return 3
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionType = sections[indexPath.section]
        let row = indexPath.row
        switch sectionType {
        case .attachments, .chatActions:
            return Constants.defaultCellHeight
        case .members:
            switch row {
            case membersRowAddMembers, membersRowQrInvite:
                return Constants.defaultCellHeight
            default:
                return ContactCell.cellHeight
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        switch sectionType {
        case .attachments:
            if row == attachmentsRowGallery {
                return galleryCell
            } else if row == attachmentsRowDocuments {
                return documentsCell
            }
        case .members:
            if row == membersRowAddMembers || row == membersRowQrInvite {
                guard let actionCell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath) as? ActionCell else {
                safe_fatalError("could not dequeue action cell")
                break
                }
                if row == membersRowAddMembers {
                    actionCell.actionTitle = String.localized("group_add_members")
                    actionCell.actionColor = UIColor.systemBlue
                } else if row == membersRowQrInvite {
                    actionCell.actionTitle = String.localized("qrshow_join_group_title")
                    actionCell.actionColor = UIColor.systemBlue
                }
                return actionCell
            }

            guard let contactCell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath) as? ContactCell else {
                safe_fatalError("could not dequeue contactCell cell")
                break
            }
            let contactId: Int = getGroupMemberIdFor(row)
            let cellData = ContactCellData(
                contactId: contactId,
                chatId: dcContext.getChatIdByContactId(contactId)
            )
            let cellViewModel = ContactCellViewModel(contactData: cellData)
            contactCell.updateCell(cellViewModel: cellViewModel)
            return contactCell
        case .chatActions:
            if row == chatActionsRowArchiveChat {
                return archiveChatCell
            } else if row == chatActionsRowLeaveGroup {
                return leaveGroupCell
            } else if row == chatActionsRowDeleteChat {
                return deleteChatCell
            }
        }
        // should never get here
        return UITableViewCell(frame: .zero)
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionType = sections[indexPath.section]
        let row = indexPath.row

        switch sectionType {
        case .attachments:
            if row == attachmentsRowGallery {
                showGallery()
            } else if row == attachmentsRowDocuments {
                showDocuments()
            }
        case .members:
            if row == membersRowAddMembers {
                showAddGroupMember(chatId: chat.id)
            } else if row == membersRowQrInvite {
                showQrCodeInvite(chatId: chat.id)
            } else {
                let member = getGroupMember(at: row)
                showContactDetail(of: member.id)
            }
        case .chatActions:
            if row == chatActionsRowArchiveChat {
                toggleArchiveChat()
            } else if row == chatActionsRowLeaveGroup {
                showLeaveGroupConfirmationAlert()
            } else if row == chatActionsRowDeleteChat {
                showDeleteChatConfirmationAlert()
            }
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == .members {
            return String.localized("tab_members")
        }
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Constants.defaultHeaderHeight
    }

    func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let currentUser = self.currentUser else {
            return false
        }
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        if sectionType == .members &&
            !isMemberManagementRow(row: row) &&
            getGroupMemberIdFor(row) != currentUser.id {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard let currentUser = self.currentUser else {
            return nil
        }
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        if sectionType == .members &&
            !isMemberManagementRow(row: row) &&
            getGroupMemberIdFor(row) != currentUser.id {
            // action set for members except for current user
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [unowned self] _, indexPath in

                let contact = self.getGroupMember(at: row)
                let title = String.localizedStringWithFormat(String.localized("ask_remove_members"), contact.nameNAddr)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("remove_desktop"), style: .destructive, handler: { _ in
                    let success = self.dcContext.removeContactFromChat(chatId: self.chat.id, contactId: contact.id)
                    if success {
                        self.removeGroupMemberFromTableAt(indexPath)
                    }
                }))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)

 }
            delete.backgroundColor = UIColor.red
            return [delete]
        }
        return nil
    }

    private func getGroupMember(at row: Int) -> DcContact {
        return DcContact(id: getGroupMemberIdFor(row))
    }

    private func removeGroupMemberFromTableAt(_ indexPath: IndexPath) {
        self.groupMemberIds.remove(at: indexPath.row - memberManagementRows)
        self.tableView.deleteRows(at: [indexPath], with: .automatic)
        updateHeader()  // to display correct group size
    }
}

// MARK: - alerts
extension GroupChatDetailViewController {
    private func showDeleteChatConfirmationAlert() {
        let alert = UIAlertController(
            title: nil,
            message: String.localized("ask_delete_chat_desktop"),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.deleteChat()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showLeaveGroupConfirmationAlert() {
        if let userId = currentUser?.id {
            let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_leave_group"), style: .destructive, handler: { _ in
                _ = self.dcContext.removeContactFromChat(chatId: self.chat.id, contactId: userId)
                self.editBarButtonItem.isEnabled = false
                self.updateGroupMembers()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}
