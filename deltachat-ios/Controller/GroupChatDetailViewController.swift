import UIKit
import DcCore
import QuickLook

class GroupChatDetailViewController: UIViewController {

    enum ProfileSections {
        case chatOptions
        case members
        case chatActions
    }

    enum ChatOption {
        case gallery
        case documents
        case ephemeralMessages
        case muteChat
    }

    enum ChatAction {
        case archiveChat
        case leaveGroup
        case deleteChat
    }

    private lazy var chatOptions: [ChatOption] = {
        return [.gallery, .documents, .ephemeralMessages, .muteChat]
    }()

    private lazy var chatActions: [ChatAction] = {
        return [.archiveChat, .leaveGroup, .deleteChat]
    }()

    private let membersRowAddMembers = 0
    private let membersRowQrInvite = 1
    private let memberManagementRows = 2

    private let dcContext: DcContext

    private let sections: [ProfileSections] = [.chatOptions, .members, .chatActions]

    private var currentUser: DcContact? {
        let myId = groupMemberIds.filter { DcContact(id: $0).email == dcContext.addr }.first
        guard let currentUserId = myId else {
            return nil
        }
        return DcContact(id: currentUserId)
    }

    private var chatId: Int
    private var chat: DcChat {
        return dcContext.getChat(chatId: chatId)
    }

    var chatIsEphemeral: Bool {
        return chatId != 0 && dcContext.getChatEphemeralTimer(chatId: chatId) > 0
    }

    private var galleryItemMessageIds: [Int] {
        return dcContext.getChatMedia(
            chatId: chatId,
            messageType: DC_MSG_IMAGE,
            messageType2: DC_MSG_GIF,
            messageType3: DC_MSG_VIDEO
        )
    }

    private var documentItemMessageIds: [Int] {
        return dcContext.getChatMedia(
            chatId: chatId,
            messageType: DC_MSG_FILE,
            messageType2: DC_MSG_AUDIO,
            messageType3: 0
        )
    }

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
        header.onAvatarTap = showGroupAvatarIfNeeded
        header.setVerified(isVerified: chat.isProtected)
        return header
    }()

    private lazy var ephemeralMessagesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("ephemeral_messages")
        cell.selectionStyle = .none
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var muteChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = self.chat.isMuted ? String.localized("menu_unmute") :  String.localized("menu_mute")
        cell.actionColor = SystemColor.blue.uiColor
        cell.selectionStyle = .none
        return cell
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
        cell.textLabel?.text = String.localized("images_and_videos")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var documentsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("files")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    init(chatId: Int, dcContext: DcContext) {
        self.dcContext = dcContext
        self.chatId = chatId
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
        updateGroupMembers()
        tableView.reloadData() // to display updates
        editBarButtonItem.isEnabled = currentUser != nil
        updateHeader()
        updateCellValues()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            groupHeader.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        }
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
        groupHeader.setVerified(isVerified: chat.isProtected)
    }

    private func updateCellValues() {
        ephemeralMessagesCell.detailTextLabel?.text = String.localized(chatIsEphemeral ? "on" : "off")
        galleryCell.detailTextLabel?.text = String.numberOrNone(galleryItemMessageIds.count)
        documentsCell.detailTextLabel?.text = String.numberOrNone(documentItemMessageIds.count)
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
        groupMemberViewController.onMembersSelected = { [weak self] (memberIds: Set<Int>) -> Void in
            guard let self = self else { return }
            let chat = self.dcContext.getChat(chatId: chatId)
            var chatMembersToRemove = chat.contactIds
            chatMembersToRemove.removeAll(where: { memberIds.contains($0)})
            for contactId in chatMembersToRemove {
                _ = self.dcContext.removeContactFromChat(chatId: chatId, contactId: contactId)
            }
            for contactId in memberIds {
                _ = self.dcContext.addContactToChat(chatId: chatId, contactId: contactId)
            }
        }
        navigationController?.pushViewController(groupMemberViewController, animated: true)
    }

    private func showQrCodeInvite(chatId: Int) {
        var hint = ""
        let dcChat = dcContext.getChat(chatId: chatId)
        if !dcChat.name.isEmpty {
            hint = String.localizedStringWithFormat(String.localized("qrshow_join_group_hint"), dcChat.name)
        }
        let qrInviteCodeController = QrViewController(dcContext: dcContext, chatId: chatId, qrCodeHint: hint)
        navigationController?.pushViewController(qrInviteCodeController, animated: true)
    }

    private func showGroupChatEdit(chat: DcChat) {
        let editGroupViewController = EditGroupViewController(dcContext: dcContext, chat: chat)
        navigationController?.pushViewController(editGroupViewController, animated: true)
    }

    private func showContactDetail(of contactId: Int) {
        let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: contactId)
        navigationController?.pushViewController(contactDetailController, animated: true)
    }

    private func showDocuments() {
        let messageIds: [Int] = documentItemMessageIds.reversed()
        let fileGalleryController = DocumentGalleryController(context: dcContext, fileMessageIds: messageIds)
        navigationController?.pushViewController(fileGalleryController, animated: true)    }

    private func showGallery() {
        let messageIds: [Int] = galleryItemMessageIds.reversed()
        let galleryController = GalleryViewController(context: dcContext, mediaMessageIds: messageIds)
        navigationController?.pushViewController(galleryController, animated: true)
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

    private func showGroupAvatarIfNeeded() {
        if let url = chat.profileImageURL {
            let previewController = PreviewController(type: .single(url))
            previewController.customTitle = self.title
            present(previewController, animated: true, completion: nil)
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
        case .chatOptions:
            return chatOptions.count
        case .members:
            return groupMemberIds.count + memberManagementRows
        case .chatActions:
            return chatActions.count
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionType = sections[indexPath.section]
        let row = indexPath.row
        if sectionType == .members && row != membersRowAddMembers && row != membersRowQrInvite {
            return ContactCell.cellHeight
        } else {
            return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        switch sectionType {
        case .chatOptions:
            switch chatOptions[row] {
            case .gallery:
                return galleryCell
            case .documents:
                return documentsCell
            case .ephemeralMessages:
                return ephemeralMessagesCell
            case .muteChat:
                return muteChatCell
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
                chatId: dcContext.getChatIdByContactIdOld(contactId)
            )
            let cellViewModel = ContactCellViewModel(contactData: cellData)
            contactCell.updateCell(cellViewModel: cellViewModel)
            return contactCell
        case .chatActions:
            switch chatActions[row] {
            case .archiveChat:
                return archiveChatCell
            case .leaveGroup:
                return leaveGroupCell
            case .deleteChat:
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
        case .chatOptions:
            switch chatOptions[row] {
            case .gallery:
                showGallery()
            case .documents:
                showDocuments()
            case .ephemeralMessages:
                showEphemeralMessagesController()
            case .muteChat:
                if chat.isMuted {
                    dcContext.setChatMuteDuration(chatId: chatId, duration: 0)
                    muteChatCell.actionTitle = String.localized("menu_mute")
                    navigationController?.popViewController(animated: true)
                } else {
                    showMuteAlert()
                }
            }
        case .members:
            if row == membersRowAddMembers {
                showAddGroupMember(chatId: chat.id)
            } else if row == membersRowQrInvite {
                showQrCodeInvite(chatId: chat.id)
            } else {
                let memberId = getGroupMemberIdFor(row)
                if memberId == DC_CONTACT_ID_SELF {
                    tableView.deselectRow(at: indexPath, animated: true)
                } else {
                    showContactDetail(of: memberId)
                }
            }
        case .chatActions:
            switch chatActions[row] {
            case .archiveChat:
                toggleArchiveChat()
            case .leaveGroup:
                showLeaveGroupConfirmationAlert()
            case .deleteChat:
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
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [weak self] _, indexPath in
                guard let self = self else { return }
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

    private func showEphemeralMessagesController() {
        let ephemeralMessagesController = SettingsEphemeralMessageController(dcContext: dcContext, chatId: chatId)
        navigationController?.pushViewController(ephemeralMessagesController, animated: true)
    }
}

// MARK: - alerts
extension GroupChatDetailViewController {

    private func showMuteAlert() {
        let alert = UIAlertController(title: String.localized("mute"), message: nil, preferredStyle: .safeActionSheet)
        let forever = -1
        addDurationSelectionAction(to: alert, key: "mute_for_one_hour", duration: Time.oneHour)
        addDurationSelectionAction(to: alert, key: "mute_for_two_hours", duration: Time.twoHours)
        addDurationSelectionAction(to: alert, key: "mute_for_one_day", duration: Time.oneDay)
        addDurationSelectionAction(to: alert, key: "mute_for_seven_days", duration: Time.oneWeek)
        addDurationSelectionAction(to: alert, key: "mute_forever", duration: forever)

        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    private func addDurationSelectionAction(to alert: UIAlertController, key: String, duration: Int) {
        let action = UIAlertAction(title: String.localized(key), style: .default, handler: { _ in
            self.dcContext.setChatMuteDuration(chatId: self.chatId, duration: duration)
            self.muteChatCell.actionTitle = String.localized("menu_unmute")
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(action)
    }

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
