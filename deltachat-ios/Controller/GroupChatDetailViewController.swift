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
        case locations
        case ephemeralMessages
    }

    enum ChatAction {
        case archiveChat
        case cloneChat
        case leaveGroup
        case clearChat
        case deleteChat
        case copyToClipboard
        case addToHomescreen
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

    // MARK: - subviews

    private lazy var editBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: String.localized("global_menu_edit_desktop"), style: .plain, target: self, action: #selector(editButtonPressed))
    }()

    lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        table.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
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
        cell.imageView?.image = UIImage(systemName: "stopwatch")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var archiveChatCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: chat.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down")
        cell.actionTitle = chat.isArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        return cell
    }()

    private lazy var cloneChatCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "square.on.square")
        cell.actionTitle = String.localized("clone_chat")
        cell.actionColor = UIColor.systemBlue
        return cell
    }()

    private lazy var leaveGroupCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "xmark")
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
        cell.imageView?.image = UIImage(systemName: "line.diagonal")
        cell.actionTitle = String.localized("clear_chat")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var deleteChatCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "trash")
        cell.actionTitle = String.localized("menu_delete_chat")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var allMediaCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("media")
        cell.imageView?.image = UIImage(systemName: "photo.on.rectangle")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var locationsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("locations")
        cell.imageView?.image = UIImage(systemName: "map")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var homescreenWidgetCell: ActionCell = {
        let cell = ActionCell()

        let chatIdsOnHomescreen: [Int]

        if #available(iOS 17, *) {
            chatIdsOnHomescreen = UserDefaults.shared!
                .getChatWidgetEntries()
                .filter { $0.accountId == dcContext.id }
                .compactMap { entry in
                    switch entry.type {
                    case .app: return nil
                    case .chat(let chatId): return chatId
                    }
                }
        } else {
            chatIdsOnHomescreen = []
        }

        let isOnHomescreen = chatIdsOnHomescreen.contains(chatId)
        cell.imageView?.image = UIImage(systemName: isOnHomescreen ? "minus.square" : "plus.square")
        cell.actionTitle = String.localized(isOnHomescreen ? "remove_from_widget" : "add_to_widget")
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

        NotificationCenter.default.addObserver(self, selector: #selector(GroupChatDetailViewController.handleIncomingMessage(_:)), name: Event.incomingMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GroupChatDetailViewController.handleChatModified(_:)), name: Event.chatModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GroupChatDetailViewController.handleEphemeralTimerModified(_:)), name: Event.ephemeralTimerModified, object: nil)
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
        updateHeader()
        updateMediaCellValues()
        updateEphemeralTimerCellValue()

        // when sharing to ourself in DocumentGalleryController,
        // end of sharing is not easily catchable nor results in applicationWillEnterForeground();
        // therefore, do the update here.
        AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            groupHeader.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        }
    }
    
    // MARK: - Notifications

    @objc private func handleEphemeralTimerModified(_ notification: Notification) {
        guard let ui = notification.userInfo,
              let chatId = ui["chat_id"] as? Int,
              self.chatId == chatId else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateEphemeralTimerCellValue()
        }
    }

    @objc private func handleChatModified(_ notification: Notification) {

        guard let ui = notification.userInfo,
              chatId == ui["chat_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateHeader()
            self?.updateGroupMembers()
            self?.updateOptions()
            self?.tableView.reloadData()
        }
    }

    @objc private func handleIncomingMessage(_ notification: Notification) {
        guard let ui = notification.userInfo, chatId == ui["chat_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateMediaCellValues()
        }
    }

    // MARK: - update
    private func updateGroupMembers() {
        groupMemberIds = chat.getContactIds(dcContext)
    }

    private func updateOptions() {
        self.editBarButtonItem.isEnabled = chat.isMailinglist || chat.canSend

        self.chatOptions = [.allMedia]
        if UserDefaults.standard.bool(forKey: "location_streaming") {
            self.chatOptions.append(.locations)
        }

        self.chatActions = [.archiveChat]
        if #available(iOS 17.0, *) {
            self.chatActions.append(.addToHomescreen)
        }

        if chat.isMailinglist {
            self.memberManagementRows = 0
            self.chatActions.append(.copyToClipboard)
            self.groupHeader.showMuteButton(show: true)
        } else if chat.isBroadcast {
            self.memberManagementRows = 1
            self.chatActions.append(.cloneChat)
            self.groupHeader.showMuteButton(show: false)
        } else if chat.canSend {
            self.chatOptions.append(.ephemeralMessages)
            self.memberManagementRows = 2
            self.chatActions.append(.cloneChat)
            self.chatActions.append(.leaveGroup)
            self.groupHeader.showMuteButton(show: true)
        } else {
            self.memberManagementRows = 0
            self.groupHeader.showMuteButton(show: true)
        }

        self.chatActions.append(.clearChat)
        self.chatActions.append(.deleteChat)
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
    private func toggleChatInHomescreenWidget() {
        guard #available(iOS 17, *),
                let userDefaults = UserDefaults.shared else { return }
        let allHomescreenChatsIds: [Int] = userDefaults
            .getChatWidgetEntries()
            .compactMap { entry in
                switch entry.type {
                case .app: return nil
                case .chat(let chatId): return chatId
                }
            }

        let onHomescreen: Bool
        if allHomescreenChatsIds.contains(chatId) {
            userDefaults.removeChatFromHomescreenWidget(accountId: dcContext.id, chatId: chatId)
            onHomescreen = false
        } else {
            userDefaults.addChatToHomescreenWidget(accountId: dcContext.id, chatId: chatId)
            onHomescreen = true
        }

        homescreenWidgetCell.imageView?.image = UIImage(systemName: onHomescreen ? "minus.square" : "plus.square")
        homescreenWidgetCell.actionTitle = String.localized(onHomescreen ? "remove_from_widget" : "add_to_widget")
    }

    @objc func editButtonPressed() {
        showGroupChatEdit(chat: chat)
    }

    private func toggleMuteChat() {
        if chat.isMuted {
            dcContext.setChatMuteDuration(chatId: chatId, duration: 0)
            groupHeader.setMuted(isMuted: false)
            navigationController?.popViewController(animated: true)
        } else {
            MuteDialog.show(viewController: self) { [weak self] duration in
                guard let self else { return }
                dcContext.setChatMuteDuration(chatId: self.chatId, duration: duration)
                groupHeader.setMuted(isMuted: true)
                navigationController?.popViewController(animated: true)
            }
        }
    }

    private func toggleArchiveChat() {
        let archivedBefore = chat.isArchived
        if !archivedBefore {
            NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        }
        dcContext.archiveChat(chatId: chat.id, archive: !archivedBefore)
        if archivedBefore {
            archiveChatCell.imageView?.image = UIImage(systemName: "tray.and.arrow.down")
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
        groupMemberViewController.onMembersSelected = { [weak self] memberIds in
            guard let self else { return }
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

    private func showLocations() {
        navigationController?.pushViewController(MapViewController(dcContext: dcContext, chatId: chatId), animated: true)
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
        if #available(iOS 17.0, *) {
            UserDefaults.shared?.removeChatFromHomescreenWidget(accountId: dcContext.id, chatId: chatId)
        }
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
            case .locations:
                return locationsCell
            case .ephemeralMessages:
                return ephemeralMessagesCell
            }
        case .members:
            if isMemberManagementRow(row: row) {
                guard let actionCell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseIdentifier, for: indexPath) as? ActionCell else {
                    fatalError("could not dequeue action cell")
                }
                if row == membersRowAddMembers {
                    actionCell.actionTitle = String.localized(chat.isBroadcast ? "add_recipients" : "group_add_members")
                    actionCell.imageView?.image = UIImage(systemName: "person.badge.plus")
                    actionCell.actionColor = UIColor.systemBlue
                } else if row == membersRowQrInvite {
                    actionCell.actionTitle = String.localized("qrshow_join_group_title")
                    actionCell.imageView?.image = UIImage(systemName: "qrcode")
                    actionCell.actionColor = UIColor.systemBlue
                }
                return actionCell
            }

            guard let contactCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell else {
                fatalError("could not dequeue contactCell cell")
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
            case .addToHomescreen:
                return homescreenWidgetCell
            }
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionType = sections[indexPath.section]
        let row = indexPath.row

        switch sectionType {
        case .chatOptions:
            switch chatOptions[row] {
            case .allMedia:
                showAllMedia()
            case .locations:
                showLocations()
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
                navigationController?.pushViewController(NewGroupController(dcContext: dcContext, createBroadcast: chat.isBroadcast, templateChatId: chatId), animated: true)
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
            case .addToHomescreen:
                tableView.deselectRow(at: indexPath, animated: true)
                toggleChatInHomescreenWidget()
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

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if chat.canSend && sections[indexPath.section] == .members && !isMemberManagementRow(row: indexPath.row) && getGroupMemberIdFor(indexPath.row) != DC_CONTACT_ID_SELF {
            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
                guard let self else { return }
                let contact = self.getGroupMember(at: indexPath.row)
                let title = String.localizedStringWithFormat(String.localized(self.chat.isBroadcast ? "ask_remove_from_broadcast" : "ask_remove_members"), contact.nameNAddr)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("remove_desktop"), style: .destructive, handler: { _ in
                    if self.dcContext.removeContactFromChat(chatId: self.chat.id, contactId: contact.id) {
                        self.removeGroupMemberFromTableAt(indexPath)
                    }
                    completionHandler(true)
                }))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            deleteAction.accessibilityLabel = String.localized("remove_desktop")
            deleteAction.image = Utils.makeImageWithText(image: UIImage(systemName: "trash"), text: String.localized("remove_desktop"))
            return UISwipeActionsConfiguration(actions: [deleteAction])
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

    private func showClearChatConfirmationAlert() {
        let msgIds = dcContext.getChatMsgs(chatId: chatId, flags: 0)
        if !msgIds.isEmpty {
            let alert = UIAlertController(
                title: nil,
                message: String.localized(stringID: "ask_delete_messages_simple", parameter: msgIds.count),
                preferredStyle: .safeActionSheet
            )
            alert.addAction(UIAlertAction(title: String.localized("clear_chat"), style: .destructive, handler: { _ in
                self.dcContext.deleteMessages(msgIds: msgIds)
                if #available(iOS 17.0, *) {
                    msgIds.forEach { UserDefaults.shared?.removeWebxdcFromHomescreen(accountId: self.dcContext.id, messageId: $0) }
                }
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
