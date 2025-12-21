import UIKit
import DcCore
import QuickLook
import Intents

class ProfileViewController: UITableViewController {

    enum Sections {
        case options
        case members
        case sharedChats
        case actions
    }

    enum Options {
        case bio
        case media
        case startChat
    }

    enum Actions {
        case verifiedBy
        case addr
    }

    enum ManageMembersActions {
        case addMembers
        case qrInvite
    }

    private var sections: [Sections] = []
    private var options: [Options] = []
    private var actions: [Actions] = []
    private var manageMembersActions: [ManageMembersActions] = []

    private let dcContext: DcContext
    private let chatId: Int
    private var chat: DcChat?
    private let contactId: Int
    private var contact: DcContact?
    private var memberIds: [Int] = []
    private var sharedChats: DcChatlist?
    private let isMultiUser, isGroup, isMailinglist, isOutBroadcast, isInBroadcast, isSavedMessages, isDeviceChat, isBot: Bool

    // MARK: - subviews

    private lazy var headerCell: ProfileHeader = {
        let header = ProfileHeader(hasSubtitle: isGroup || isOutBroadcast)
        header.onAvatarTap = showEnlargedAvatar
        header.setRecentlySeen(contact?.wasSeenRecently ?? false)
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
        if let contact {
            cell.imageView?.image = UIImage(named: "verified")?.scaleDownImage(toMax: 21.0)

            let verifierId = contact.getVerifierId()
            let verifiedInfo: String
            if verifierId == 0 {
                cell.accessoryType = .none
                verifiedInfo = String.localized("verified_by_unknown")
            } else if verifierId == DC_CONTACT_ID_SELF {
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

    private lazy var addrCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.imageView?.image = UIImage(systemName: "server.rack")
        if let contact {
            cell.textLabel?.text = contact.email
        } else if isMailinglist, let chat {
            cell.textLabel?.text = chat.getMailinglistAddr()
        }
        let copyContactGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(ProfileViewController.showCopyToClipboard))
        cell.addGestureRecognizer(copyContactGestureRecognizer)
        return cell
    }()

    private lazy var mediaCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("apps_and_media")
        cell.imageView?.image = UIImage(systemName: "square.grid.2x2")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var startChatCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.textLabel?.text = String.localized("send_message")
        cell.imageView?.image = UIImage(systemName: "paperplane")
        return cell
    }()

    // MARK: - constructor

    init(_ dcContext: DcContext, chatId: Int = 0, contactId: Int = 0) {
        self.dcContext = dcContext
        self.contactId = contactId
        self.chatId = contactId != 0 ? dcContext.getChatIdByContactId(contactId) : chatId
        self.chat = self.chatId != 0 ? dcContext.getChat(chatId: self.chatId) : nil
        self.contact = self.contactId != 0 ? dcContext.getContact(id: self.contactId) : nil

        isMultiUser = chat?.isMultiUser ?? false
        isGroup = (chat?.type ?? 0) == DC_CHAT_TYPE_GROUP
        isOutBroadcast = chat?.isOutBroadcast ?? false
        isInBroadcast = chat?.isInBroadcast ?? false
        isMailinglist = chat?.isMailinglist ?? false
        isSavedMessages = chat?.isSelfTalk ?? false
        isDeviceChat = chat?.isDeviceTalk ?? false
        isBot = contact?.isBot ?? false
        sharedChats = if contactId != 0, !isSavedMessages, !isDeviceChat { dcContext.getChatlist(flags: 0, queryString: nil, queryId: contactId) } else { nil }

        sections.append(.options)
        if isMultiUser && !isMailinglist && !isInBroadcast {
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
        } else if isOutBroadcast || isInBroadcast {
            title = String.localized("channel")
        } else if isMultiUser {
            title = String.localized("tab_group")
        } else if isBot {
            title = String.localized("bot")
        } else if !isDeviceChat && !isSavedMessages {
            title = String.localized("tab_contact")
        } else {
            title = String.localized("profile")
        }

        headerCell.frame = CGRect(0, 0, tableView.frame.width, headerCell.headerHeight)
        tableView.tableHeaderView = headerCell
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateMembers()
        updateOptions()
        tableView.reloadData()
        updateHeader()
        updateMediaCellValues()
        updateMenuItems()

        // when sharing to ourself in DocumentGalleryController,
        // end of sharing is not easily catchable nor results in applicationWillEnterForeground();
        // therefore, do the update here.
        AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            headerCell.frame = CGRect(0, 0, tableView.frame.width, headerCell.headerHeight)
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
            self?.updateMenuItems()
            self?.tableView.reloadData()
        }
    }

    @objc private func handleContactsChanged(_ notification: Notification) {
        guard let ui = notification.userInfo, contactId == ui["contact_id"] as? Int else { return }
        contact = dcContext.getContact(id: contactId)

        DispatchQueue.main.async { [weak self] in
            self?.updateMenuItems()
            self?.updateHeader()
        }
    }

    @objc private func handleEphemeralTimerModified(_ notification: Notification) {
        guard let ui = notification.userInfo, chatId == ui["chat_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateMenuItems()
        }
    }

    @objc private func handleIncomingMessage(_ notification: Notification) {
        guard let ui = notification.userInfo, let changedChatId = ui["chat_id"] as? Int else { return }

        if changedChatId == chatId {
            updateMediaCellValues()
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
        manageMembersActions = []

        if isSavedMessages || !(contact?.status.isEmpty ?? true) {
            options.append(.bio)
        }

        if !isSavedMessages && !isDeviceChat, let contact, contact.isVerified {
            actions.append(.verifiedBy)
        }

        if contact != nil && !isSavedMessages && !isDeviceChat {
            actions.append(.addr)
        } else if let chat, isMailinglist, !chat.getMailinglistAddr().isEmpty {
            actions.append(.addr)
        }

        options.append(.media) // add unconditionally, to have a visual anchor

        if let chat {
            if isOutBroadcast {
                manageMembersActions.append(.qrInvite)
            } else if isGroup && chat.canSend && chat.isEncrypted {
                manageMembersActions.append(.addMembers)
                manageMembersActions.append(.qrInvite)
            }
        }

        if contact != nil && !isSavedMessages && !isDeviceChat {
            options.append(.startChat)
        }
    }

    private func updateMenuItems() {
        let menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: moreButtonMenu())
        var buttonItems: [UIBarButtonItem] = [menuButton]
        if !isSavedMessages && !isDeviceChat && contact != nil {
            let editButton = UIBarButtonItem(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(showEditController))
            editButton.accessibilityLabel = String.localized("global_menu_edit_desktop")
            buttonItems.append(editButton)
        }
        navigationItem.setRightBarButtonItems(buttonItems, animated: false)
    }

    private func moreButtonMenu() -> UIMenu {
        func action(_ localized: String, _ systemImage: String, attributes: UIMenuElement.Attributes = [], _ handler: @escaping () -> Void) -> UIAction {
            UIAction(title: String.localized(localized), image: UIImage(systemName: systemImage), attributes: attributes, handler: { _ in handler() })
        }

        func actions() -> [UIMenuElement] {
            var actions = [UIMenuElement]()
            var moreOptions = [UIMenuElement]()
            var primaryOptions = [UIMenuElement]() // max. 3 due to .medium element size

            if contact != nil, !isSavedMessages && !isDeviceChat {
                primaryOptions.append(action("menu_share", "square.and.arrow.up", shareContact))
            } else if isMultiUser && !isMailinglist && (chat?.canSend ?? false) && (chat?.isEncrypted ?? false) {
                primaryOptions.append(action("global_menu_edit_desktop", "pencil", showEditController))
            }
            if let chat, !isOutBroadcast && !isSavedMessages {
                primaryOptions.append(action(chat.isMuted ? "menu_unmute" : "mute", chat.isMuted ? "speaker.wave.2" : "speaker.slash", toggleMuteChat))
            }
            if let chat, chat.canSend { // search is buggy in combination with contact request panel, that needs to be fixed if we want to allow search in general
                primaryOptions.append(action("search", "magnifyingglass", showSearch))
            }
            let primaryMenu = UIMenu(options: [.displayInline], children: primaryOptions)
            if #available(iOS 16.0, *), primaryOptions.count > 1 {
                primaryMenu.preferredElementSize = .medium
            }
            actions.append(contentsOf: [primaryMenu])

            if let chat, chat.isEncrypted, chat.canSend {
                let ephemeralTimer = dcContext.getChatEphemeralTimer(chatId: chatId)
                let action = action("ephemeral_messages", "stopwatch", showEphemeralController)
                action.state = ephemeralTimer > 0 ? .on : .off
                if ephemeralTimer > 0, #available(iOS 15.0, *) {
                    action.subtitle = EphemeralMessagesViewController.getValString(val: ephemeralTimer)
                }
                actions.append(action)
            }

            if let chat {
                actions.append(action(chat.isArchived ? "menu_unarchive_chat" : "menu_archive_chat", chat.isArchived ? "tray.and.arrow.up" : "tray.and.arrow.down", toggleArchiveChat))
            }

            if chat != nil, #available(iOS 17.0, *), let userDefaults = UserDefaults.shared {
                let isOnHomescreen = userDefaults.getChatWidgetEntriesFor(contextId: dcContext.id).contains(chatId)
                actions.append(action(isOnHomescreen ? "remove_from_widget" : "add_to_widget", isOnHomescreen ? "minus.square" : "plus.square", toggleChatInWidget))
            }

            if let contact, !isSavedMessages && !isDeviceChat {
                moreOptions.append(action("encryption_info_title_desktop", "info.circle", showEncrInfoAlert))
                moreOptions.append(action(contact.isBlocked ? "menu_unblock_contact" : "menu_block_contact", "nosign", attributes: [.destructive], toggleBlockContact))
            }

            if let chat {
                if isMultiUser && !isMailinglist && !isInBroadcast && !isOutBroadcast {
                    let image = if #available(iOS 15.0, *) { "rectangle.portrait.on.rectangle.portrait" } else { "square.on.square" }
                    moreOptions.append(action("clone_chat", image, showCloneChatController))
                }

                let leaveImage = if #available(iOS 15.0, *) { "rectangle.portrait.and.arrow.right" } else { "arrow.right.square" }
                let clearImage = if #available(iOS 16.0, *) { "eraser" } else { "rectangle.portrait" }
                if isGroup && chat.canSend && chat.isEncrypted {
                    moreOptions.append(action("menu_leave_group", leaveImage, attributes: [.destructive], { [weak self] in
                        self?.showLeaveAlert("menu_leave_group")
                    }))
                    moreOptions.append(action("clear_chat", clearImage, attributes: [.destructive], showClearConfirmationAlert))
                } else if isInBroadcast {
                    moreOptions.append(action("menu_leave_channel", leaveImage, attributes: [.destructive], { [weak self] in
                        self?.showLeaveAlert("menu_leave_channel")
                    }))
                    moreOptions.append(action("clear_chat", clearImage, attributes: [.destructive], showClearConfirmationAlert))
                } else {
                    moreOptions.append(action("clear_chat", clearImage, attributes: [.destructive], showClearConfirmationAlert))
                }

                moreOptions.append(action("menu_delete_chat", "trash", attributes: [.destructive], showDeleteConfirmationAlert))
            }

            if !moreOptions.isEmpty {
                actions.append(contentsOf: [
                    UIMenu(options: [.displayInline], children: moreOptions)
                ])
            }

            return actions
        }

        return UIMenu(children: [
            UIDeferredMenuElement({ completion in
                completion(actions())
            })
        ])
    }

    private func updateHeader() {
        if let chat {
            let subtitle: String?
            if isOutBroadcast {
                subtitle = String.localized(stringID: "n_recipients", parameter: chat.getContactIds(dcContext).count)
            } else if isGroup {
                let chatContactIds = chat.getContactIds(dcContext)
                if chatContactIds.count > 1 || chatContactIds.contains(Int(DC_CONTACT_ID_SELF)) {
                    subtitle = String.localized(stringID: "n_members", parameter: chatContactIds.count)
                } else {
                    // do not show misleading "1 member" in case securejoin has not finished
                    subtitle = nil
                }
            } else {
                subtitle = nil
            }

            headerCell.updateDetails(title: chat.name, subtitle: subtitle)
            if let img = chat.profileImage {
                headerCell.setImage(img)
            } else {
                headerCell.setBackupImage(name: chat.name, color: chat.color)
            }
        } else if let contact {
            headerCell.updateDetails(title: contact.displayName)
            if let img = contact.profileImage {
                headerCell.setImage(img)
            } else {
                headerCell.setBackupImage(name: contact.displayName, color: contact.color)
            }
        }
    }

    private func updateMediaCellValues() {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let label = chatId == 0 ? String.localized("none") : dcContext.getAllMediaCountString(chatId: chatId)
            DispatchQueue.main.async { [weak self] in
                self?.mediaCell.detailTextLabel?.text = label
            }
        }
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

    // MARK: - actions, coordinators

    @objc func showEditController() {
        if contact != nil {
            navigationController?.pushViewController(EditContactController(dcContext: dcContext, contactIdForUpdate: contactId), animated: true)
        } else if let chat, isMultiUser {
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
            navigationController?.popViewController(animated: true)
        } else {
            MuteDialog.show(viewController: self) { [weak self] duration in
                guard let self else { return }
                dcContext.setChatMuteDuration(chatId: chatId, duration: duration)
                navigationController?.popViewController(animated: true)
            }
        }
    }

    private func showEnlargedAvatar() {
        if let chat {
            if chat.isEncrypted && !chat.isSelfTalk && !chat.isDeviceTalk, let url = chat.profileImageURL {
                let previewController = PreviewController(dcContext: dcContext, type: .single(url))
                previewController.customTitle = chat.name
                navigationController?.pushViewController(previewController, animated: true)
            }
        } else if let contact {
            if contact.isKeyContact, let url = contact.profileImageURL {
                let previewController = PreviewController(dcContext: dcContext, type: .single(url))
                previewController.customTitle = contact.displayName
                navigationController?.pushViewController(previewController, animated: true)
            }
        }
    }

    @objc private func showCopyToClipboard() {
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: String.localized("menu_copy_to_clipboard"), action: #selector(ProfileViewController.copyToClipboard))
        ]
        UIMenuController.shared.showMenu(from: addrCell.textLabel ?? addrCell, rect: addrCell.textLabel?.frame ?? addrCell.frame)
    }

    @objc private func copyToClipboard() {
        if let chat, isMailinglist {
            UIPasteboard.general.string = chat.getMailinglistAddr()
        } else if let contact {
            UIPasteboard.general.string = contact.email
        }
    }

    private func showMedia() {
        if chatId != 0 {
            navigationController?.pushViewController(AllMediaViewController(dcContext: dcContext, chatId: chatId), animated: true)
        }
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
        guard let contact else { return }
        if contact.isKeyContact {
            guard let vcardData = dcContext.makeVCard(contactIds: [contactId]) else { return }
            RelayHelper.shared.setForwardVCard(vcardData: vcardData)
        } else {
            RelayHelper.shared.setForwardMessage(dialogTitle: String.localized("chat_share_with_title"), text: contact.email, fileData: nil, fileName: nil)
        }
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
        self.chat = dcContext.getChat(chatId: chatId)
        if archivedBefore {
            updateMenuItems()
        } else {
            navigationController?.popToRootViewController(animated: false)
        }
    }

    private func toggleChatInWidget() {
        guard #available(iOS 17, *), let userDefaults = UserDefaults.shared else { return }
        if userDefaults.getChatWidgetEntriesFor(contextId: dcContext.id).contains(chatId) {
            userDefaults.removeChatFromHomescreenWidget(accountId: dcContext.id, chatId: chatId)
        } else {
            userDefaults.addChatToHomescreenWidget(accountId: dcContext.id, chatId: chatId)
        }
        updateMenuItems()
    }

    private func showEncrInfoAlert() {
        let encrInfo = dcContext.getContactEncrInfo(contactId: contactId)
        let alert = UIAlertController(title: String.localized("encryption_info_title_desktop"), message: encrInfo, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("global_menu_edit_copy_desktop"), style: .default, handler: { _ in
            UIPasteboard.general.string = encrInfo
        }))
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default))
        self.present(alert, animated: true, completion: nil)
    }

    private func showCloneChatController() {
        navigationController?.pushViewController(NewGroupController(dcContext: dcContext, createMode: isOutBroadcast ? .createBroadcast : .createGroup, templateChatId: chatId), animated: true)
    }

    private func showLeaveAlert(_ buttonLabel: String) {
        let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized(buttonLabel), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            _ = dcContext.removeContactFromChat(chatId: chatId, contactId: Int(DC_CONTACT_ID_SELF))
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func showClearConfirmationAlert() {
        guard chat != nil else { return }
        let msgIds = dcContext.getChatMsgs(chatId: chatId, flags: 0)
        if !msgIds.isEmpty {
            let alert = UIAlertController(title: nil, message: String.localized(stringID: "ask_delete_messages", parameter: msgIds.count), preferredStyle: .safeActionSheet)
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
        return row < manageMembersActions.count
    }

    private func getMemberIdFor(_ row: Int) -> Int {
        let index = row - manageMembersActions.count
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
        case .options:
            return options.count
        case .members:
            return manageMembersActions.count + memberIds.count
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
        case .options:
            switch options[indexPath.row] {
            case .bio:
                return statusCell
            case .media:
                return mediaCell
            case .startChat:
                return startChatCell
            }
        case .members:
            if isMemberManagementRow(row: indexPath.row) {
                guard let actionCell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseIdentifier, for: indexPath) as? ActionCell else { return UITableViewCell() }
                switch manageMembersActions[indexPath.row] {
                case .addMembers:
                    actionCell.actionTitle = String.localized("group_add_members")
                    actionCell.imageView?.image = UIImage(systemName: "plus")
                    actionCell.actionColor = UIColor.systemBlue
                case .qrInvite:
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
            case .verifiedBy:
                return verifiedByCell
            case .addr:
                return addrCell
            }
        }
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .options:
            switch options[indexPath.row] {
            case .bio:
                break
            case .media:
                tableView.deselectRow(at: indexPath, animated: true)
                showMedia()
            case .startChat:
                showChat(otherChatId: dcContext.createChatByContactId(contactId: contactId))
            }
        case .members:
            if isMemberManagementRow(row: indexPath.row) {
                guard let chat else { return }
                switch manageMembersActions[indexPath.row] {
                case .addMembers:
                    showAddGroupMember(chatId: chat.id)
                case .qrInvite:
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
            case .verifiedBy:
                guard let contact else { return }
                tableView.deselectRow(at: indexPath, animated: true)
                let verifierId = contact.getVerifierId()
                if verifierId != 0 && verifierId != DC_CONTACT_ID_SELF {
                    showContactDetail(of: verifierId)
                }
            case .addr:
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == .sharedChats {
            return String.localized("profile_shared_chats")
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if sections[section] == .options {
            guard let contact, contact.lastSeen != 0, !isSavedMessages, !isDeviceChat else { return nil }
            return String.localizedStringWithFormat(String.localized("last_seen_relative"), DateUtils.getExtendedAbsTimeSpanString(timeStamp: Double(contact.lastSeen)))
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let chat else { return nil }
        if chat.canSend && chat.isEncrypted && sections[indexPath.section] == .members && !isMemberManagementRow(row: indexPath.row) && getMemberIdFor(indexPath.row) != DC_CONTACT_ID_SELF {
            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
                guard let self else { return }
                let otherContact = dcContext.getContact(id: getMemberIdFor(indexPath.row))
                let title = String.localizedStringWithFormat(String.localized(isOutBroadcast ? "ask_remove_from_channel" : "ask_remove_members"), otherContact.displayName)
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
        memberIds.remove(at: indexPath.row - manageMembersActions.count)
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

                var contactId = dcContext.lookupContactIdByAddress(email)
                if contactId == 0 {
                    contactId = dcContext.createContact(name: "", email: email)
                }

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
