import UIKit
import DcCore
import QuickLook
import Intents

class GroupChatDetailViewController: UIViewController {

    enum ProfileSections {
        case chatOptions
        case members
        case chatActions
    }

    enum ChatOption {
        case allMedia
        case ephemeralMessages
    }

    enum ChatAction {
        case archiveChat
        case cloneChat
        case leaveGroup
        case clearChat
        case deleteChat
        case copyToClipboard
    }

    private var chatOptions: [ChatOption]
    private var chatActions: [ChatAction]

    private let membersRowAddMembers = 0
    private let membersRowQrInvite = 1
    private var memberManagementRows: Int

    private let dcContext: DcContext

    private let sections: [ProfileSections]

    private var chatId: Int
    private var chat: DcChat {
        return dcContext.getChat(chatId: chatId)
    }

    var chatIsEphemeral: Bool {
        return chatId != 0 && dcContext.getChatEphemeralTimer(chatId: chatId) > 0
    }

    // stores contactIds
    private var groupMemberIds: [Int] = []
    
    private var incomingMsgsObserver: NSObjectProtocol?
    private var ephemeralTimerObserver: NSObjectProtocol?
    private var chatModifiedObserver: NSObjectProtocol?

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
        header.onAvatarTap = showGroupAvatarIfNeeded
        header.showMuteButton(show: chat.isMuted)
        header.showSearchButton(show: true)
        header.onSearchButtonTapped = showSearch
        header.onMuteButtonTapped = toggleMuteChat
        header.setRecentlySeen(false)
        return header
    }()

    private lazy var ephemeralMessagesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("ephemeral_messages")
        if #available(iOS 13.0, *) {
            cell.imageView?.image = UIImage(named: "ephemeral_timer")?.withTintColor(UIColor.systemBlue)
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var archiveChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = chat.isArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        cell.actionColor = UIColor.systemBlue
        return cell
    }()

    private lazy var cloneChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("clone_chat")
        cell.actionColor = UIColor.systemBlue
        return cell
    }()

    private lazy var leaveGroupCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_leave_group")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var copyToClipboardCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_copy_to_clipboard")
        cell.actionColor = UIColor.systemBlue
        return cell
    }()

    private lazy var clearChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("clear_chat")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var deleteChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_delete_chat")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var allMediaCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("media")
        if #available(iOS 13.0, *) {
            cell.imageView?.image = UIImage(systemName: "photo.on.rectangle") // added in ios13
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    init(chatId: Int, dcContext: DcContext) {
        self.dcContext = dcContext
        self.chatId = chatId

        let chat = dcContext.getChat(chatId: chatId)
        self.chatActions = []
        self.chatOptions = []
        self.memberManagementRows = 0
        if chat.isMailinglist {
            self.sections = [.chatOptions, .chatActions]
        } else if chat.isBroadcast {
            self.sections = [.chatOptions, .members, .chatActions]
        } else {
            self.sections = [.chatOptions, .members, .chatActions]
        }

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
        if chat.isMailinglist {
            title = String.localized("mailing_list")
        } else if chat.isBroadcast {
            title = String.localized("broadcast_list")
        } else {
            title = String.localized("tab_group")
        }
        navigationItem.rightBarButtonItem = editBarButtonItem
        groupHeader.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateGroupMembers()
        updateOptions()
        tableView.reloadData()

        setupObservers()
        updateHeader()
        updateMediaCellValues()
        updateEphemeralTimerCellValue()

        // when sharing to ourself in DocumentGalleryController,
        // end of sharing is not easily catchable nor results in applicationWillEnterForeground();
        // therefore, do the update here.
        AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        removeObservers()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            groupHeader.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        }
    }
    
    // MARK: - observers
    private func setupObservers() {
        let nc = NotificationCenter.default
        incomingMsgsObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil,
            queue: OperationQueue.main) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo,
               self.chatId == ui["chat_id"] as? Int {
                self.updateMediaCellValues()
            }
        }
        ephemeralTimerObserver = nc.addObserver(
            forName: dcEphemeralTimerModified,
            object: nil,
            queue: OperationQueue.main) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo,
               self.chatId == ui["chat_id"] as? Int {
                self.updateEphemeralTimerCellValue()
            }
        }
        chatModifiedObserver = nc.addObserver(
            forName: dcNotificationChatModified,
            object: nil,
            queue: OperationQueue.main) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo,
               self.chatId == ui["chat_id"] as? Int {
                self.updateHeader()
                self.updateGroupMembers()
                self.updateOptions()
                self.tableView.reloadData()
            }
        }
    }
    
    private func removeObservers() {
        let nc = NotificationCenter.default
        if let msgChangedObserver = self.incomingMsgsObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let ephemeralTimerObserver = self.ephemeralTimerObserver {
            nc.removeObserver(ephemeralTimerObserver)
        }
        if let chatModifiedObserver = self.chatModifiedObserver {
            nc.removeObserver(chatModifiedObserver)
        }
    }

    // MARK: - update
    private func updateGroupMembers() {
        groupMemberIds = chat.getContactIds(dcContext)
    }

    private func updateOptions() {
        self.editBarButtonItem.isEnabled = chat.isMailinglist || chat.canSend

        if chat.isMailinglist {
            self.chatOptions = [.allMedia]
            self.memberManagementRows = 0
            self.chatActions = [.archiveChat, .copyToClipboard, .clearChat, .deleteChat]
            self.groupHeader.showMuteButton(show: true)
        } else if chat.isBroadcast {
            self.chatOptions = [.allMedia]
            self.memberManagementRows = 1
            self.chatActions = [.archiveChat, .cloneChat, .clearChat, .deleteChat]
            self.groupHeader.showMuteButton(show: false)
        } else if chat.canSend {
            self.chatOptions = [.allMedia, .ephemeralMessages]
            self.memberManagementRows = 2
            self.chatActions = [.archiveChat, .cloneChat, .leaveGroup, .clearChat, .deleteChat]
            self.groupHeader.showMuteButton(show: true)
        } else {
            self.chatOptions = [.allMedia]
            self.memberManagementRows = 0
            self.chatActions = [.archiveChat, .clearChat, .deleteChat]
            self.groupHeader.showMuteButton(show: true)
        }
    }

    private func updateHeader() {
        var subtitle: String?
        if chat.isMailinglist {
            let addr = chat.getMailinglistAddr()
            subtitle = addr.isEmpty ? nil : addr
        }
        groupHeader.updateDetails(title: chat.name, subtitle: subtitle)

        if let img = chat.profileImage {
            groupHeader.setImage(img)
        } else {
            groupHeader.setBackupImage(name: chat.name, color: chat.color)
        }
        groupHeader.setGreenCheckmark(greenCheckmark: chat.isProtected)
        groupHeader.setMuted(isMuted: chat.isMuted)
        groupHeader.showSearchButton(show: chat.canSend)
    }

    private func updateEphemeralTimerCellValue() {
        ephemeralMessagesCell.detailTextLabel?.text = String.localized(chatIsEphemeral ? "on" : "off")
    }
    
    private func updateMediaCellValues() {
        allMediaCell.detailTextLabel?.text = dcContext.getAllMediaCount(chatId: chatId)
    }

    // MARK: - actions
    @objc func editButtonPressed() {
        showGroupChatEdit(chat: chat)
    }

    private func toggleMuteChat() {
        if chat.isMuted {
            dcContext.setChatMuteDuration(chatId: chatId, duration: 0)
            groupHeader.setMuted(isMuted: false)
            navigationController?.popViewController(animated: true)
        } else {
            showMuteAlert()
        }
    }

    private func toggleArchiveChat() {
        let archivedBefore = chat.isArchived
        if !archivedBefore {
            NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        }
        dcContext.archiveChat(chatId: chat.id, archive: !archivedBefore)
        if archivedBefore {
            archiveChatCell.actionTitle = String.localized("menu_archive_chat")
        } else {
            self.navigationController?.popToRootViewController(animated: false)
        }
     }

    private func getGroupMemberIdFor(_ row: Int) -> Int {
        let index = row - memberManagementRows
        if index >= 0 && index < groupMemberIds.count {
            return groupMemberIds[index]
        } else {
            return 0
        }
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
        let groupMemberViewController = AddGroupMembersViewController(dcContext: dcContext, chatId: chatId)
        groupMemberViewController.onMembersSelected = { [weak self] (memberIds: Set<Int>) -> Void in
            guard let self = self else { return }
            let chat = self.dcContext.getChat(chatId: chatId)
            var chatMembersToRemove = chat.getContactIds(self.dcContext)
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

    private func showAllMedia() {
        navigationController?.pushViewController(AllMediaViewController(dcContext: dcContext, chatId: chatId), animated: true)
    }

    private func showSearch() {
        if let chatViewController = navigationController?.viewControllers.last(where: {
            $0 is ChatViewController
        }) as? ChatViewController {
            chatViewController.activateSearchOnAppear()
            navigationController?.popViewController(animated: true)
        }
    }

    private func deleteChat() {
        dcContext.deleteChat(chatId: chatId)
        NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        INInteraction.delete(with: ["\(dcContext.id).\(chatId)"])
        navigationController?.popViewControllers(viewsToPop: 2, animated: true)
    }

    private func showGroupAvatarIfNeeded() {
        if let url = chat.profileImageURL {
            let previewController = PreviewController(dcContext: dcContext, type: .single(url))
            previewController.customTitle = self.title
            navigationController?.pushViewController(previewController, animated: true)
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
        if sectionType == .members && !isMemberManagementRow(row: row) {
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
            case .allMedia:
                return allMediaCell
            case .ephemeralMessages:
                return ephemeralMessagesCell
            }
        case .members:
            if isMemberManagementRow(row: row) {
                guard let actionCell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath) as? ActionCell else {
                safe_fatalError("could not dequeue action cell")
                break
                }
                if row == membersRowAddMembers {
                    actionCell.actionTitle = String.localized(chat.isBroadcast ? "add_recipients" : "group_add_members")
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
            let cellViewModel = ContactCellViewModel(dcContext: dcContext, contactData: cellData)
            contactCell.updateCell(cellViewModel: cellViewModel)
            return contactCell
        case .chatActions:
            switch chatActions[row] {
            case .archiveChat:
                return archiveChatCell
            case .cloneChat:
                return cloneChatCell
            case .leaveGroup:
                return leaveGroupCell
            case .clearChat:
                return clearChatCell
            case .deleteChat:
                return deleteChatCell
            case .copyToClipboard:
                return copyToClipboardCell
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
            case .allMedia:
                showAllMedia()
            case .ephemeralMessages:
                showEphemeralMessagesController()
            }
        case .members:
            if isMemberManagementRow(row: row) {
                if row == membersRowAddMembers {
                    showAddGroupMember(chatId: chat.id)
                } else if row == membersRowQrInvite {
                    showQrCodeInvite(chatId: chat.id)
                }
            } else {
                let memberId = getGroupMemberIdFor(row)
                if memberId == DC_CONTACT_ID_SELF {
                    tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
                } else {
                    showContactDetail(of: memberId)
                }
            }
        case .chatActions:
            switch chatActions[row] {
            case .archiveChat:
                tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
                toggleArchiveChat()
            case .cloneChat:
                tableView.deselectRow(at: indexPath, animated: false)
            case .leaveGroup:
                tableView.deselectRow(at: indexPath, animated: false)
                showLeaveGroupConfirmationAlert()
            case .clearChat:
                tableView.deselectRow(at: indexPath, animated: false)
                showClearChatConfirmationAlert()
            case .deleteChat:
                tableView.deselectRow(at: indexPath, animated: false)
                showDeleteChatConfirmationAlert()
            case .copyToClipboard:
                tableView.deselectRow(at: indexPath, animated: false)
                UIPasteboard.general.string = chat.getMailinglistAddr()

            }
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == .members {
            return String.localizedStringWithFormat(String.localized(chat.isBroadcast ? "n_recipients" : "n_members"),
                                                    chat.getContactIds(dcContext).count)
        }
        return nil
    }

    func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if !chat.canSend {
            return false
        }
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        if sectionType == .members &&
            !isMemberManagementRow(row: row) &&
            getGroupMemberIdFor(row) != DC_CONTACT_ID_SELF {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if !chat.canSend {
            return nil
        }
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        if sectionType == .members &&
            !isMemberManagementRow(row: row) &&
            getGroupMemberIdFor(row) != DC_CONTACT_ID_SELF {
            // action set for members except for current user
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [weak self] _, indexPath in
                guard let self = self else { return }
                let contact = self.getGroupMember(at: row)
                let title = String.localizedStringWithFormat(String.localized(self.chat.isBroadcast ?
                                     "ask_remove_from_broadcast" :
                                        "ask_remove_members"), contact.nameNAddr)
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
            delete.backgroundColor = UIColor.systemRed
            return [delete]
        }
        return nil
    }

    private func getGroupMember(at row: Int) -> DcContact {
        return dcContext.getContact(id: getGroupMemberIdFor(row))
    }

    private func removeGroupMemberFromTableAt(_ indexPath: IndexPath) {
        self.groupMemberIds.remove(at: indexPath.row - memberManagementRows)
        self.tableView.deleteRows(at: [indexPath], with: .automatic)
        updateHeader()  // to display correct group size
    }

    private func showEphemeralMessagesController() {
        let ephemeralMessagesController = EphemeralMessagesViewController(dcContext: dcContext, chatId: chatId)
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
            self.groupHeader.setMuted(isMuted: true)
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(action)
    }

    private func showClearChatConfirmationAlert() {
        let msgIds = dcContext.getChatMsgs(chatId: chatId)
        if !msgIds.isEmpty {
            let alert = UIAlertController(
                title: nil,
                message: String.localized(stringID: "ask_delete_messages_simple", count: msgIds.count),
                preferredStyle: .safeActionSheet
            )
            alert.addAction(UIAlertAction(title: String.localized("clear_chat"), style: .destructive, handler: { _ in
                self.dcContext.deleteMessages(msgIds: msgIds)
                self.navigationController?.popViewController(animated: true)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func showDeleteChatConfirmationAlert() {
        let alert = UIAlertController(
            title: nil,
            message: String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), dcContext.getChat(chatId: chatId).name),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.deleteChat()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showLeaveGroupConfirmationAlert() {
        let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("menu_leave_group"), style: .destructive, handler: { _ in
            _ = self.dcContext.removeContactFromChat(chatId: self.chat.id, contactId: Int(DC_CONTACT_ID_SELF))
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
