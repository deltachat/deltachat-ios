import UIKit
import DcCore
import QuickLook
import Intents

class GroupChatDetailViewController: UITableViewController {

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

    private let sections: [ProfileSections]
    private var chatOptions: [ChatOption]
    private var chatActions: [ChatAction]

    private let membersRowAddMembers = 0
    private let membersRowQrInvite = 1
    private var memberManagementRows: Int

    private let dcContext: DcContext
    private let chatId: Int
    private var chat: DcChat?
    private var groupMemberIds: [Int] = []

    // MARK: - subviews

    private lazy var editBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: String.localized("global_menu_edit_desktop"), style: .plain, target: self, action: #selector(editButtonPressed))
    }()

    private lazy var groupHeader: ContactDetailHeader = {
        let header = ContactDetailHeader()
        header.onAvatarTap = showGroupAvatarIfNeeded
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
        if let chat {
            cell.imageView?.image = UIImage(systemName: chat.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down")
            cell.actionTitle = chat.isArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        }
        return cell
    }()

    private lazy var cloneChatCell: ActionCell = {
        let cell = ActionCell()
        let image = if #available(iOS 15.0, *) { "rectangle.portrait.on.rectangle.portrait" } else { "square.on.square" }
        cell.imageView?.image = UIImage(systemName: image)
        cell.actionTitle = String.localized("clone_chat")
        cell.actionColor = UIColor.systemBlue
        return cell
    }()

    private lazy var leaveGroupCell: ActionCell = {
        let cell = ActionCell()
        let image = if #available(iOS 15.0, *) { "rectangle.portrait.and.arrow.right" } else { "arrow.right.square" }
        cell.imageView?.image = UIImage(systemName: image)
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
        let image = if #available(iOS 16.0, *) { "eraser" } else { "rectangle.portrait" }
        cell.imageView?.image = UIImage(systemName: image)
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

    // MARK: - constructor

    init(chatId: Int, dcContext: DcContext) {
        self.dcContext = dcContext
        self.chatId = chatId
        chat = chatId != 0 ? dcContext.getChat(chatId: chatId) : nil

        chatActions = []
        chatOptions = []
        memberManagementRows = 0
        if let chat {
            if chat.isMailinglist {
                sections = [.chatOptions, .chatActions]
            } else if chat.isBroadcast {
                sections = [.chatOptions, .members, .chatActions]
            } else if chat.isGroup {
                sections = [.chatOptions, .members, .chatActions]
            } else {
                sections = [.chatOptions, .chatActions]
            }
        } else {
            sections = [.chatOptions, .chatActions]
        }

        super.init(style: .insetGrouped)

        NotificationCenter.default.addObserver(self, selector: #selector(GroupChatDetailViewController.handleIncomingMessage(_:)), name: Event.incomingMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GroupChatDetailViewController.handleChatModified(_:)), name: Event.chatModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(GroupChatDetailViewController.handleEphemeralTimerModified(_:)), name: Event.ephemeralTimerModified, object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        if let chat {
            if chat.isMailinglist {
                title = String.localized("mailing_list")
            } else if chat.isBroadcast {
                title = String.localized("broadcast_list")
            } else {
                title = String.localized("tab_group")
            }
        }
        navigationItem.rightBarButtonItem = editBarButtonItem
        groupHeader.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        tableView.tableHeaderView = groupHeader
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
        guard let ui = notification.userInfo, chatId == ui["chat_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateEphemeralTimerCellValue()
        }
    }

    @objc private func handleChatModified(_ notification: Notification) {
        guard let ui = notification.userInfo, chatId == ui["chat_id"] as? Int else { return }

        chat = dcContext.getChat(chatId: chatId)

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
        guard let chat else { return }
        groupMemberIds = chat.getContactIds(dcContext)
    }

    private func updateOptions() {
        if let chat {
            editBarButtonItem.isEnabled = chat.isMailinglist || chat.canSend

            chatOptions = [.allMedia]
            if UserDefaults.standard.bool(forKey: "location_streaming") {
                chatOptions.append(.locations)
            }

            chatActions = [.archiveChat]
            if #available(iOS 17.0, *) {
                chatActions.append(.addToHomescreen)
            }

            if chat.isMailinglist {
                memberManagementRows = 0
                chatActions.append(.copyToClipboard)
                groupHeader.showMuteButton(show: true)
            } else if chat.isBroadcast {
                memberManagementRows = 1
                chatActions.append(.cloneChat)
                groupHeader.showMuteButton(show: false)
            } else if chat.canSend {
                chatOptions.append(.ephemeralMessages)
                memberManagementRows = 2
                chatActions.append(.cloneChat)
                chatActions.append(.leaveGroup)
                groupHeader.showMuteButton(show: true)
            } else {
                memberManagementRows = 0
                groupHeader.showMuteButton(show: true)
            }

            chatActions.append(.clearChat)
            chatActions.append(.deleteChat)
        }
    }

    private func updateHeader() {
        if let chat {
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
    }

    private func updateEphemeralTimerCellValue() {
        let chatIsEphemeral = chatId != 0 && dcContext.getChatEphemeralTimer(chatId: chatId) > 0
        ephemeralMessagesCell.detailTextLabel?.text = String.localized(chatIsEphemeral ? "on" : "off")
    }
    
    private func updateMediaCellValues() {
        allMediaCell.detailTextLabel?.text = dcContext.getAllMediaCount(chatId: chatId)
    }

    // MARK: - actions, coordinators

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
        guard let chat else { return }
        let editGroupViewController = EditGroupViewController(dcContext: dcContext, chat: chat)
        navigationController?.pushViewController(editGroupViewController, animated: true)
    }

    private func toggleMuteChat() {
        guard let chat else { return }
        if chat.isMuted {
            dcContext.setChatMuteDuration(chatId: chatId, duration: 0)
            groupHeader.setMuted(isMuted: false)
            navigationController?.popViewController(animated: true)
        } else {
            MuteDialog.show(viewController: self) { [weak self] duration in
                guard let self else { return }
                dcContext.setChatMuteDuration(chatId: chatId, duration: duration)
                groupHeader.setMuted(isMuted: true)
                navigationController?.popViewController(animated: true)
            }
        }
    }

    private func toggleArchiveChat() {
        guard let chat else { return }
        let archivedBefore = chat.isArchived
        if !archivedBefore {
            NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        }
        dcContext.archiveChat(chatId: chat.id, archive: !archivedBefore)
        if archivedBefore {
            archiveChatCell.imageView?.image = UIImage(systemName: "tray.and.arrow.down")
            archiveChatCell.actionTitle = String.localized("menu_archive_chat")
        } else {
            navigationController?.popToRootViewController(animated: false)
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

    private func showSingleChatEdit(contactId: Int) {
        let editContactController = EditContactController(dcContext: dcContext, contactIdForUpdate: contactId)
        navigationController?.pushViewController(editContactController, animated: true)
    }

    private func showAddGroupMember(chatId: Int) {
        let groupMemberViewController = AddGroupMembersViewController(dcContext: dcContext, chatId: chatId)
        groupMemberViewController.onMembersSelected = { [weak self] memberIds in
            guard let self else { return }
            let chat = dcContext.getChat(chatId: chatId)
            var chatMembersToRemove = chat.getContactIds(dcContext)
            chatMembersToRemove.removeAll(where: { memberIds.contains($0)})
            for contactId in chatMembersToRemove {
                _ = dcContext.removeContactFromChat(chatId: chatId, contactId: contactId)
            }
            for contactId in memberIds {
                _ = dcContext.addContactToChat(chatId: chatId, contactId: contactId)
            }
        }
        navigationController?.pushViewController(groupMemberViewController, animated: true)
    }

    private func showQrCodeInvite(chatId: Int) {
        guard let chat else { return }
        var hint = ""
        if !chat.name.isEmpty {
            hint = String.localizedStringWithFormat(String.localized("qrshow_join_group_hint"), chat.name)
        }
        let qrInviteCodeController = QrViewController(dcContext: dcContext, chatId: chatId, qrCodeHint: hint)
        navigationController?.pushViewController(qrInviteCodeController, animated: true)
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

    private func showEphemeralMessagesController() {
        let ephemeralMessagesController = EphemeralMessagesViewController(dcContext: dcContext, chatId: chatId)
        navigationController?.pushViewController(ephemeralMessagesController, animated: true)
    }

    private func showClearChatConfirmationAlert() {
        guard chat != nil else { return }
        let msgIds = dcContext.getChatMsgs(chatId: chatId, flags: 0)
        if !msgIds.isEmpty {
            let alert = UIAlertController(
                title: nil,
                message: Utils.askDeleteMsgsText(count: msgIds.count),
                preferredStyle: .safeActionSheet
            )
            alert.addAction(UIAlertAction(title: String.localized("clear_chat"), style: .destructive, handler: { [weak self] _ in
                guard let self else { return }
                dcContext.deleteMessages(msgIds: msgIds)
                if #available(iOS 17.0, *) {
                    msgIds.forEach { UserDefaults.shared?.removeWebxdcFromHomescreen(accountId: self.dcContext.id, messageId: $0) }
                }
                navigationController?.popViewController(animated: true)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    private func showDeleteChatConfirmationAlert() {
        guard let chat else { return }
        let alert = UIAlertController(
            title: nil,
            message: String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), chat.name),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            dcContext.deleteChat(chatId: chatId)
            NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
            if #available(iOS 17.0, *) {
                UserDefaults.shared?.removeChatFromHomescreenWidget(accountId: dcContext.id, chatId: chatId)
            }
            INInteraction.delete(with: ["\(dcContext.id).\(chatId)"])
            navigationController?.popViewControllers(viewsToPop: 2, animated: true)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func showLeaveGroupConfirmationAlert() {
        guard let chat, chat.isGroup else { return }
        let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("menu_leave_group"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            _ = dcContext.removeContactFromChat(chatId: chat.id, contactId: Int(DC_CONTACT_ID_SELF))
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func showGroupAvatarIfNeeded() {
        guard let chat else { return }
        if let url = chat.profileImageURL {
            let previewController = PreviewController(dcContext: dcContext, type: .single(url))
            previewController.customTitle = title
            navigationController?.pushViewController(previewController, animated: true)
        }
    }

    // MARK: - UITableViewDatasource, UITableViewDelegate

    private func isMemberManagementRow(row: Int) -> Bool {
        return row < memberManagementRows
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
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

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionType = sections[indexPath.section]
        let row = indexPath.row
        if sectionType == .members && !isMemberManagementRow(row: row) {
            return ContactCell.cellHeight
        } else {
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
                guard let chat, let actionCell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseIdentifier, for: indexPath) as? ActionCell else {
                    fatalError("could not dequeue action cell")
                }
                if row == membersRowAddMembers {
                    actionCell.actionTitle = String.localized(chat.isBroadcast ? "add_recipients" : "group_add_members")
                    actionCell.imageView?.image = UIImage(systemName: "plus")
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

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
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
                guard let chat else { return }
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
                guard let chat else { return }
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
                guard let chat else { return }
                tableView.deselectRow(at: indexPath, animated: false)
                UIPasteboard.general.string = chat.getMailinglistAddr()
            case .addToHomescreen:
                tableView.deselectRow(at: indexPath, animated: true)
                toggleChatInHomescreenWidget()
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == .members {
            guard let chat else { return nil }
            return String.localizedStringWithFormat(String.localized(chat.isBroadcast ? "n_recipients" : "n_members"),
                                                    chat.getContactIds(dcContext).count)
        }
        return nil
    }

    override func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let chat, chat.canSend else { return false }
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        if sectionType == .members &&
            !isMemberManagementRow(row: row) &&
            getGroupMemberIdFor(row) != DC_CONTACT_ID_SELF {
            return true
        }
        return false
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let chat else { return nil }
        if chat.canSend && sections[indexPath.section] == .members && !isMemberManagementRow(row: indexPath.row) && getGroupMemberIdFor(indexPath.row) != DC_CONTACT_ID_SELF {
            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
                guard let self else { return }
                let contact = getGroupMember(at: indexPath.row)
                let title = String.localizedStringWithFormat(String.localized(chat.isBroadcast ? "ask_remove_from_broadcast" : "ask_remove_members"), contact.displayName)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("remove_desktop"), style: .destructive, handler: { [weak self] _ in
                    guard let self else { return }
                    if dcContext.removeContactFromChat(chatId: chat.id, contactId: contact.id) {
                        removeGroupMemberFromTableAt(indexPath)
                    }
                    completionHandler(true)
                }))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
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
        groupMemberIds.remove(at: indexPath.row - memberManagementRows)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateHeader()  // to display correct group size
    }
}
