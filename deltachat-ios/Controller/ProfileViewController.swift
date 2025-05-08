import UIKit
import DcCore
import QuickLook
import Intents

class ProfileViewController: UITableViewController {

    enum Sections {
        case bio
        case options
        case members
        case sharedChats
        case actions
    }

    enum Options {
        case verifiedBy
        case media
        case locations
        case ephemeral
        case startChat
        case shareContact
    }

    enum Actions {
        case archive
        case addToWidget
        case encrInfo
        case clone
        case leaveGroup
        case clear
        case delete
        case block
    }

    private var sections: [Sections] = []
    private var options: [Options] = []
    private var actions: [Actions] = []

    private let membersRowAddMembers = 0
    private let membersRowQrInvite = 1
    private var memberManagementRows: Int = 0

    private let dcContext: DcContext
    private let chatId: Int
    private var chat: DcChat?
    private let contactId: Int
    private var contact: DcContact?
    private var memberIds: [Int] = []
    private var sharedChats: DcChatlist?
    private let isGroup, isMailinglist, isBroadcast, isSavedMessages, isDeviceChat, isBot: Bool

    // MARK: - subviews

    private lazy var headerCell: ContactDetailHeader = {
        let header = ContactDetailHeader()
        header.onAvatarTap = showEnlargedAvatar
        header.onSearchButtonTapped = showSearch
        header.onMuteButtonTapped = toggleMuteChat
        header.setRecentlySeen(contact?.wasSeenRecently ?? false)
        if (contact != nil && !isSavedMessages && !isDeviceChat) || isMailinglist {
            let copyContactGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(ProfileViewController.showCopyToClipboard))
            header.labelsContainer.addGestureRecognizer(copyContactGestureRecognizer)
        }
        return header
    }()

    private lazy var statusCell: MultilineLabelCell = {
        let cell = MultilineLabelCell()
        cell.multilineDelegate = self
        cell.setText(text: isSavedMessages ? String.localized("saved_messages_explain") : (contact?.status ?? ""))
        return cell
    }()

    private lazy var verifiedByCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.imageView?.image = UIImage(named: "verified")?.scaleDownImage(toMax: 24)
        if let contact {
            let verifierId = contact.getVerifierId()
            let verifiedInfo: String
            if verifierId == DC_CONTACT_ID_SELF {
                cell.accessoryType = .none
                verifiedInfo = String.localized("verified_by_you")
            } else {
                cell.accessoryType = .disclosureIndicator
                verifiedInfo = String.localizedStringWithFormat(String.localized("verified_by"), dcContext.getContact(id: verifierId).displayName)
            }
            cell.textLabel?.text = verifiedInfo
        }
        return cell
    }()

    private lazy var mediaCell: UITableViewCell = {
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

    private lazy var ephemeralCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("ephemeral_messages")
        cell.imageView?.image = UIImage(systemName: "stopwatch")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var startChatCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "paperplane")
        cell.actionTitle = String.localized("send_message")
        return cell
    }()

    private lazy var shareContactCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "square.and.arrow.up")
        cell.actionTitle = String.localized("menu_share")
        return cell
    }()

    private lazy var archiveCell: ActionCell = {
        let cell = ActionCell()
        if let chat {
            cell.imageView?.image = UIImage(systemName: chat.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down")
            cell.actionTitle = chat.isArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        }
        return cell
    }()

    private lazy var addToWidgetCell: ActionCell = {
        let cell = ActionCell()
        if #available(iOS 17, *), let userDefaults = UserDefaults.shared {
            let isOnHomescreen = userDefaults.getChatWidgetEntriesFor(contextId: dcContext.id).contains(chatId)
            cell.imageView?.image = UIImage(systemName: isOnHomescreen ? "minus.square" : "plus.square")
            cell.actionTitle = String.localized(isOnHomescreen ? "remove_from_widget" : "add_to_widget")
        }
        return cell
    }()

    private lazy var encrInfoCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "info.circle")
        cell.actionTitle = String.localized("encryption_info_title_desktop")
        return cell
    }()

    private lazy var cloneCell: ActionCell = {
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

    private lazy var clearCell: ActionCell = {
        let cell = ActionCell()
        let image = if #available(iOS 16.0, *) { "eraser" } else { "rectangle.portrait" }
        cell.imageView?.image = UIImage(systemName: image)
        cell.actionTitle = String.localized("clear_chat")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var deleteCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "trash")
        cell.actionTitle = String.localized("menu_delete_chat")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var blockCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "nosign")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    // MARK: - constructor

    init(_ dcContext: DcContext, chatId: Int = 0, contactId: Int = 0) {
        self.dcContext = dcContext
        self.contactId = contactId
        self.chatId = contactId != 0 ? dcContext.getChatIdByContactId(contactId: contactId) : chatId
        self.chat = self.chatId != 0 ? dcContext.getChat(chatId: self.chatId) : nil
        self.contact = self.contactId != 0 ? dcContext.getContact(id: self.contactId) : nil

        isGroup = chat?.isGroup ?? false
        isBroadcast = chat?.isBroadcast ?? false
        isMailinglist = chat?.isMailinglist ?? false
        isSavedMessages = chat?.isSelfTalk ?? false
        isDeviceChat = chat?.isDeviceTalk ?? false
        isBot = contact?.isBot ?? false
        sharedChats = if contactId != 0, !isSavedMessages, !isDeviceChat { dcContext.getChatlist(flags: 0, queryString: nil, queryId: contactId) } else { nil }

        if isSavedMessages || !(contact?.status.isEmpty ?? true) {
            sections.append(.bio)
        }
        sections.append(.options)
        if isBroadcast || isGroup {
            sections.append(.members)
        }
        if let sharedChats, sharedChats.length > 0 {
            sections.append(.sharedChats)
        }
        sections.append(.actions)

        super.init(style: .insetGrouped)

        NotificationCenter.default.addObserver(self, selector: #selector(ProfileViewController.handleIncomingMessage(_:)), name: Event.incomingMessage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ProfileViewController.handleChatModified(_:)), name: Event.chatModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ProfileViewController.handleEphemeralTimerModified(_:)), name: Event.ephemeralTimerModified, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ProfileViewController.handleContactsChanged(_:)), name: Event.contactsChanged, object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        if isMailinglist {
            title = String.localized("mailing_list")
        } else if isBroadcast {
            title = String.localized("broadcast_list")
        } else if isGroup {
            title = String.localized("tab_group")
        } else if isBot {
            title = String.localized("bot")
        } else if !isDeviceChat && !isSavedMessages {
            title = String.localized("tab_contact")
        } else {
            title = String.localized("profile")
        }

        if !isSavedMessages && !isDeviceChat && (contact != nil || isMailinglist || (isGroup && chat?.canSend ?? false)) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: String.localized("global_menu_edit_desktop"), style: .plain, target: self, action: #selector(showEditController))
        }

        headerCell.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        tableView.tableHeaderView = headerCell
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateMembers()
        updateOptions()
        tableView.reloadData()
        updateHeader()
        updateMediaCellValues()
        updateEphemeralCellValue()
        updateBlockCell()

        // when sharing to ourself in DocumentGalleryController,
        // end of sharing is not easily catchable nor results in applicationWillEnterForeground();
        // therefore, do the update here.
        AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            headerCell.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        }
    }
    
    // MARK: - Notifications

    @objc private func handleChatModified(_ notification: Notification) {
        guard let ui = notification.userInfo, chatId == ui["chat_id"] as? Int else { return }
        chat = dcContext.getChat(chatId: chatId)

        DispatchQueue.main.async { [weak self] in
            self?.updateHeader()
            self?.updateMembers()
            self?.updateOptions()
            self?.tableView.reloadData()
        }
    }

    @objc private func handleContactsChanged(_ notification: Notification) {
        guard let ui = notification.userInfo, contactId == ui["contact_id"] as? Int else { return }
        contact = dcContext.getContact(id: contactId)

        DispatchQueue.main.async { [weak self] in
            self?.updateBlockCell()
            self?.updateHeader()
        }
    }

    @objc private func handleEphemeralTimerModified(_ notification: Notification) {
        guard let ui = notification.userInfo, chatId == ui["chat_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateEphemeralCellValue()
        }
    }

    @objc private func handleIncomingMessage(_ notification: Notification) {
        guard let ui = notification.userInfo, let changedChatId = ui["chat_id"] as? Int else { return }

        if changedChatId == chatId {
            DispatchQueue.main.async { [weak self] in
                self?.updateMediaCellValues()
            }
        }

        if sharedChatIdsContain(chatId: changedChatId) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                sharedChats = dcContext.getChatlist(flags: 0, queryString: nil, queryId: contactId)
                tableView.reloadData()
            }
        }
    }

    // MARK: - update

    private func updateOptions() {
        options = []
        actions = []

        headerCell.showMuteButton(show: chat != nil && !isBroadcast && !isSavedMessages)

        if let contact, contact.getVerifierId() != 0 {
            options.append(.verifiedBy)
        }

        if chat != nil {
            options.append(.media)
            if UserDefaults.standard.bool(forKey: "location_streaming") {
                options.append(.locations)
            }
            actions.append(.archive)
            if #available(iOS 17.0, *) {
                actions.append(.addToWidget)
            }
        }

        if contact != nil && !isSavedMessages && !isDeviceChat {
            actions.append(.encrInfo)
        }

        memberManagementRows = 0
        if let chat {
            if isBroadcast {
                memberManagementRows = 1
                actions.append(.clone)
            } else if chat.canSend {
                options.append(.ephemeral)
                if isGroup {
                    memberManagementRows = 2
                    actions.append(.clone)
                    actions.append(.leaveGroup)
                }
            }
            actions.append(.clear)
            actions.append(.delete)
        }

        if contact != nil && !isSavedMessages && !isDeviceChat {
            options.append(.startChat)
            options.append(.shareContact)
            actions.append(.block)
        }
    }

    private func updateHeader() {
        if let chat {
            var subtitle: String?
            if isMailinglist {
                let addr = chat.getMailinglistAddr()
                subtitle = addr.isEmpty ? nil : addr
            }
            headerCell.updateDetails(title: chat.name, subtitle: subtitle)
            if let img = chat.profileImage {
                headerCell.setImage(img)
            } else {
                headerCell.setBackupImage(name: chat.name, color: chat.color)
            }
            headerCell.setGreenCheckmark(greenCheckmark: chat.isProtected)
            headerCell.setMuted(isMuted: chat.isMuted)
            headerCell.showSearchButton(show: chat.canSend) // search is buggy in combination with contact request panel, that needs to be fixed if we want to allow search in general
        } else if let contact {
            headerCell.updateDetails(title: contact.displayName, subtitle: isDeviceChat ? String.localized("device_talk_subtitle") : contact.email)
            if let img = contact.profileImage {
                headerCell.setImage(img)
            } else {
                headerCell.setBackupImage(name: contact.displayName, color: contact.color)
            }
            headerCell.setGreenCheckmark(greenCheckmark: contact.isVerified)
            headerCell.showMuteButton(show: false)
            headerCell.showSearchButton(show: false)
        }
    }

    private func updateMediaCellValues() {
        mediaCell.detailTextLabel?.text = dcContext.getAllMediaCount(chatId: chatId)
    }

    private func updateEphemeralCellValue() {
        let chatIsEphemeral = chatId != 0 && dcContext.getChatEphemeralTimer(chatId: chatId) > 0
        ephemeralCell.detailTextLabel?.text = String.localized(chatIsEphemeral ? "on" : "off")
    }

    private func updateMembers() {
        guard let chat else { return }
        memberIds = chat.getContactIds(dcContext)
    }

    private func updateSharedChat(cell: ContactCell, row index: Int) {
        guard let sharedChats else { return }
        let chatId = sharedChats.getChatId(index: index)
        let summary = sharedChats.getSummary(index: index)
        let unreadMessages = dcContext.getUnreadMessages(chatId: chatId)
        let cellData = ChatCellData(chatId: chatId, highlightMsgId: nil, summary: summary, unreadMessages: unreadMessages)
        let cellViewModel = ChatCellViewModel(dcContext: dcContext, chatData: cellData)
        cell.updateCell(cellViewModel: cellViewModel)
        cell.backgroundColor = DcColors.profileCellBackgroundColor
    }

    private func updateBlockCell() {
        guard let contact else { return }
        blockCell.actionTitle = contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
    }

    // MARK: - actions, coordinators

    @objc func showEditController() {
        if contact != nil {
            navigationController?.pushViewController(EditContactController(dcContext: dcContext, contactIdForUpdate: contactId), animated: true)
        } else if let chat, isGroup {
            navigationController?.pushViewController(EditGroupViewController(dcContext: dcContext, chat: chat), animated: true)
        }
    }

    private func showSearch() {
        if let chatViewController = navigationController?.viewControllers.last(where: {
            $0 is ChatViewController
        }) as? ChatViewController {
            chatViewController.activateSearchOnAppear()
            navigationController?.popViewController(animated: true)
        }
    }

    private func toggleMuteChat() {
        guard let chat else { return }
        if chat.isMuted {
            dcContext.setChatMuteDuration(chatId: chatId, duration: 0)
            headerCell.setMuted(isMuted: false)
            navigationController?.popViewController(animated: true)
        } else {
            MuteDialog.show(viewController: self) { [weak self] duration in
                guard let self else { return }
                dcContext.setChatMuteDuration(chatId: chatId, duration: duration)
                headerCell.setMuted(isMuted: true)
                navigationController?.popViewController(animated: true)
            }
        }
    }

    private func showEnlargedAvatar() {
        if let chat, let url = chat.profileImageURL {
            let previewController = PreviewController(dcContext: dcContext, type: .single(url))
            previewController.customTitle = chat.name
            navigationController?.pushViewController(previewController, animated: true)
        } else if let contact, let url = contact.profileImageURL {
            let previewController = PreviewController(dcContext: dcContext, type: .single(url))
            previewController.customTitle = contact.displayName
            navigationController?.pushViewController(previewController, animated: true)
        }
    }

    @objc private func showCopyToClipboard() {
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: String.localized("menu_copy_to_clipboard"), action: #selector(ProfileViewController.copyToClipboard))
        ]
        UIMenuController.shared.showMenu(from: headerCell.titleLabelContainer, rect: headerCell.titleLabelContainer.frame)
    }

    @objc private func copyToClipboard() {
        if let chat, isMailinglist {
            UIPasteboard.general.string = chat.getMailinglistAddr()
        } else if let contact {
            UIPasteboard.general.string = contact.email
        }
    }

    private func showMedia() {
        navigationController?.pushViewController(AllMediaViewController(dcContext: dcContext, chatId: chatId), animated: true)
    }

    private func showLocations() {
        navigationController?.pushViewController(MapViewController(dcContext: dcContext, chatId: chatId), animated: true)
    }

    private func showEphemeralController() {
        navigationController?.pushViewController(EphemeralMessagesViewController(dcContext: dcContext, chatId: chatId), animated: true)
    }

    private func showChat(otherChatId: Int) {
        if let chatlistViewController = navigationController?.viewControllers[0] as? ChatListViewController {
            let chatViewController = ChatViewController(dcContext: dcContext, chatId: otherChatId)
            chatlistViewController.backButtonUpdateableDataSource = chatViewController
            navigationController?.setViewControllers([chatlistViewController, chatViewController], animated: true)
        }
    }

    private func shareContact() {
        guard let vcardData = dcContext.makeVCard(contactIds: [contactId]) else { return }
        RelayHelper.shared.setForwardVCard(vcardData: vcardData)
        navigationController?.popToRootViewController(animated: true)
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
        let hint = String.localizedStringWithFormat(String.localized("qrshow_join_group_hint"), chat.name)
        navigationController?.pushViewController(QrViewController(dcContext: dcContext, chatId: chatId, qrCodeHint: hint), animated: true)
    }

    private func showContactDetail(of contactId: Int) {
        navigationController?.pushViewController(ProfileViewController(dcContext, contactId: contactId), animated: true)
    }

    private func toggleArchiveChat() {
        guard let chat else { return }
        let archivedBefore = chat.isArchived
        if !archivedBefore {
            NotificationManager.removeNotificationsForChat(dcContext: dcContext, chatId: chatId)
        }
        dcContext.archiveChat(chatId: chat.id, archive: !archivedBefore)
        if archivedBefore {
            archiveCell.imageView?.image = UIImage(systemName: "tray.and.arrow.down")
            archiveCell.actionTitle = String.localized("menu_archive_chat")
        } else {
            navigationController?.popToRootViewController(animated: false)
        }
    }

    private func toggleChatInHomescreenWidget() {
        guard #available(iOS 17, *), let userDefaults = UserDefaults.shared else { return }
        let onHomescreen: Bool
        if userDefaults.getChatWidgetEntriesFor(contextId: dcContext.id).contains(chatId) {
            userDefaults.removeChatFromHomescreenWidget(accountId: dcContext.id, chatId: chatId)
            onHomescreen = false
        } else {
            userDefaults.addChatToHomescreenWidget(accountId: dcContext.id, chatId: chatId)
            onHomescreen = true
        }
        addToWidgetCell.imageView?.image = UIImage(systemName: onHomescreen ? "minus.square" : "plus.square")
        addToWidgetCell.actionTitle = String.localized(onHomescreen ? "remove_from_widget" : "add_to_widget")
    }

    private func showEncrInfoAlert() {
        let alert = UIAlertController(title: String.localized("encryption_info_title_desktop"), message: dcContext.getContactEncrInfo(contactId: contactId), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default))
        self.present(alert, animated: true, completion: nil)
    }

    private func showLeaveGroupConfirmationAlert() {
        guard let chat, isGroup else { return }
        let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("menu_leave_group"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            _ = dcContext.removeContactFromChat(chatId: chat.id, contactId: Int(DC_CONTACT_ID_SELF))
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func showClearConfirmationAlert() {
        guard chat != nil else { return }
        let msgIds = dcContext.getChatMsgs(chatId: chatId, flags: 0)
        if !msgIds.isEmpty {
            let alert = UIAlertController(title: nil, message: Utils.askDeleteMsgsText(count: msgIds.count), preferredStyle: .safeActionSheet)
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

    private func showDeleteConfirmationAlert() {
        guard let chat else { return }
        let alert = UIAlertController(title: nil, message: String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), chat.name), preferredStyle: .safeActionSheet)
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

    private func toggleBlockContact() {
        guard let contact else { return }
        if contact.isBlocked {
            let alert = UIAlertController(title: String.localized("ask_unblock_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_unblock_contact"), style: .default, handler: { [weak self] _ in
                guard let self else { return }
                dcContext.unblockContact(id: contactId)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String.localized("ask_block_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_block_contact"), style: .destructive, handler: { [weak self] _ in
                guard let self else { return }
                dcContext.blockContact(id: contactId)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        }
    }

    // MARK: - UITableViewDatasource, UITableViewDelegate

    private func isMemberManagementRow(row: Int) -> Bool {
        return row < memberManagementRows
    }

    private func getMemberIdFor(_ row: Int) -> Int {
        let index = row - memberManagementRows
        if index >= 0 && index < memberIds.count {
            return memberIds[index]
        } else {
            return 0
        }
    }

    func sharedChatIdsContain(chatId: Int) -> Bool {
        guard let sharedChats else { return false }
        for n in 0..<sharedChats.length {
            if sharedChats.getChatId(index: n) == chatId {
                return true
            }
        }
        return false
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .bio:
            return 1
        case .options:
            return options.count
        case .members:
            return memberIds.count + memberManagementRows
        case .sharedChats:
            return sharedChats?.length ?? 0
        case .actions:
            return actions.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (sections[indexPath.section] == .members && !isMemberManagementRow(row: indexPath.row))
         || sections[indexPath.section] == .sharedChats {
            return ContactCell.cellHeight
        } else {
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .bio:
            return statusCell
        case .options:
            switch options[indexPath.row] {
            case .verifiedBy:
                return verifiedByCell
            case .media:
                return mediaCell
            case .locations:
                return locationsCell
            case .ephemeral:
                return ephemeralCell
            case .startChat:
                return startChatCell
            case .shareContact:
                return shareContactCell
            }
        case .members:
            if isMemberManagementRow(row: indexPath.row) {
                guard let actionCell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseIdentifier, for: indexPath) as? ActionCell else { return UITableViewCell() }
                if indexPath.row == membersRowAddMembers {
                    actionCell.actionTitle = String.localized(isBroadcast ? "add_recipients" : "group_add_members")
                    actionCell.imageView?.image = UIImage(systemName: "plus")
                    actionCell.actionColor = UIColor.systemBlue
                } else if indexPath.row == membersRowQrInvite {
                    actionCell.actionTitle = String.localized("qrshow_join_group_title")
                    actionCell.imageView?.image = UIImage(systemName: "qrcode")
                    actionCell.actionColor = UIColor.systemBlue
                }
                return actionCell
            }

            guard let contactCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell else { return UITableViewCell() }
            let contactId: Int = getMemberIdFor(indexPath.row)
            let cellData = ContactCellData(
                contactId: contactId,
                chatId: dcContext.getChatIdByContactIdOld(contactId)
            )
            let cellViewModel = ContactCellViewModel(dcContext: dcContext, contactData: cellData)
            contactCell.updateCell(cellViewModel: cellViewModel)
            return contactCell
        case .sharedChats:
            guard let sharedChatCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell else { return UITableViewCell() }
            updateSharedChat(cell: sharedChatCell, row: indexPath.row)
            return sharedChatCell
        case .actions:
            switch actions[indexPath.row] {
            case .archive:
                return archiveCell
            case .addToWidget:
                return addToWidgetCell
            case .encrInfo:
                return encrInfoCell
            case .clone:
                return cloneCell
            case .leaveGroup:
                return leaveGroupCell
            case .clear:
                return clearCell
            case .delete:
                return deleteCell
            case .block:
                return blockCell
            }
        }
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .bio:
            break
        case .options:
            switch options[indexPath.row] {
            case .verifiedBy:
                guard let contact else { return }
                tableView.deselectRow(at: indexPath, animated: true)
                let verifierId = contact.getVerifierId()
                if verifierId != 0 && verifierId != DC_CONTACT_ID_SELF {
                    showContactDetail(of: verifierId)
                }
            case .media:
                showMedia()
            case .locations:
                showLocations()
            case .ephemeral:
                showEphemeralController()
            case .startChat:
                showChat(otherChatId: dcContext.createChatByContactId(contactId: contactId))
            case .shareContact:
                shareContact()
            }
        case .members:
            if isMemberManagementRow(row: indexPath.row) {
                guard let chat else { return }
                if indexPath.row == membersRowAddMembers {
                    showAddGroupMember(chatId: chat.id)
                } else if indexPath.row == membersRowQrInvite {
                    showQrCodeInvite(chatId: chat.id)
                }
            } else {
                let memberId = getMemberIdFor(indexPath.row)
                if memberId == DC_CONTACT_ID_SELF {
                    tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
                } else {
                    showContactDetail(of: memberId)
                }
            }
        case .sharedChats:
            showChat(otherChatId: sharedChats?.getChatId(index: indexPath.row) ?? 0)
        case .actions:
            switch actions[indexPath.row] {
            case .archive:
                tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
                toggleArchiveChat()
            case .addToWidget:
                tableView.deselectRow(at: indexPath, animated: true)
                toggleChatInHomescreenWidget()
            case .encrInfo:
                tableView.deselectRow(at: indexPath, animated: false)
                showEncrInfoAlert()
            case .clone:
                tableView.deselectRow(at: indexPath, animated: false)
                navigationController?.pushViewController(NewGroupController(dcContext: dcContext, createBroadcast: isBroadcast, templateChatId: chatId), animated: true)
            case .leaveGroup:
                tableView.deselectRow(at: indexPath, animated: false)
                showLeaveGroupConfirmationAlert()
            case .clear:
                tableView.deselectRow(at: indexPath, animated: false)
                showClearConfirmationAlert()
            case .delete:
                tableView.deselectRow(at: indexPath, animated: false)
                showDeleteConfirmationAlert()
            case .block:
                tableView.deselectRow(at: indexPath, animated: false)
                toggleBlockContact()
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == .members {
            guard let chat else { return nil }
            return String.localizedStringWithFormat(String.localized(isBroadcast ? "n_recipients" : "n_members"), chat.getContactIds(dcContext).count)
        } else if sections[section] == .sharedChats {
            return String.localized("profile_shared_chats")
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let contact, sections[section] == .options, !isSavedMessages, !isDeviceChat {
            if contact.lastSeen == 0 {
                return String.localized("last_seen_unknown")
            } else {
                return String.localizedStringWithFormat(String.localized("last_seen_at"), DateUtils.getExtendedAbsTimeSpanString(timeStamp: Double(contact.lastSeen)))
            }
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let chat else { return nil }
        if chat.canSend && sections[indexPath.section] == .members && !isMemberManagementRow(row: indexPath.row) && getMemberIdFor(indexPath.row) != DC_CONTACT_ID_SELF {
            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
                guard let self else { return }
                let otherContact = dcContext.getContact(id: getMemberIdFor(indexPath.row))
                let title = String.localizedStringWithFormat(String.localized(isBroadcast ? "ask_remove_from_broadcast" : "ask_remove_members"), otherContact.displayName)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("remove_desktop"), style: .destructive, handler: { [weak self] _ in
                    guard let self else { return }
                    if dcContext.removeContactFromChat(chatId: chat.id, contactId: otherContact.id) {
                        removeMemberFromTableAt(indexPath)
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

    private func removeMemberFromTableAt(_ indexPath: IndexPath) {
        memberIds.remove(at: indexPath.row - memberManagementRows)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateHeader()
    }
}

extension ProfileViewController: MultilineLabelCellDelegate {
    func phoneNumberTapped(number: String) {
        let sanitizedNumber = number.filter("0123456789".contains)
        guard let phoneURL = URL(string: "tel://\(sanitizedNumber)") else { return }
        UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
    }

    func urlTapped(url: URL) {
        if Utils.isEmail(url: url) {
            let email = Utils.getEmailFrom(url)
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), email), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { [weak self] _ in
                guard let self, let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                let contactId = dcContext.createContact(name: "", email: email)
                appDelegate.appCoordinator.showChat(chatId: dcContext.createChatByContactId(contactId: contactId), clearViewControllerStack: true)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else if Utils.isProxy(url: url, dcContext: dcContext), let appDelegate = UIApplication.shared.delegate as? AppDelegate, let appCoordinator = appDelegate.appCoordinator {
            appCoordinator.handleProxySelection(on: self, dcContext: dcContext, proxyURL: url.absoluteString)
        } else if url.isDeltaChatInvitation, let appDelegate = UIApplication.shared.delegate as? AppDelegate, let appCoordinator = appDelegate.appCoordinator {
            appCoordinator.handleDeltaChatInvitation(url: url, from: self)
        } else {
            UIApplication.shared.open(url)
        }
    }
}
