import UIKit
import DcCore
import Intents

class ContactDetailViewController: UITableViewController {
    private let viewModel: ContactDetailViewModel

    private lazy var headerCell: ContactDetailHeader = {
        let headerCell = ContactDetailHeader()
        headerCell.showSearchButton(show: viewModel.chatId != 0)
        headerCell.onAvatarTap = showContactAvatarIfNeeded
        headerCell.onMuteButtonTapped = toggleMuteChat
        headerCell.onSearchButtonTapped = showSearch
        headerCell.setRecentlySeen(viewModel.contact.wasSeenRecently)

        if viewModel.isSavedMessages == false && viewModel.isDeviceTalk == false {
            let copyContactGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(ContactDetailViewController.showCopyToClipboard))
            headerCell.labelsContainer.addGestureRecognizer(copyContactGestureRecognizer)
        }

        return headerCell
    }()


    private lazy var startChatCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.imageView?.image = UIImage(systemName: "paperplane")
        cell.textLabel?.text = String.localized("send_message")
        cell.textLabel?.textColor = UIColor.systemBlue
        return cell
    }()

    private lazy var homescreenWidgetCell: ActionCell = {
        let cell = ActionCell()

        let chatIdsOnHomescreen: [Int]

        if #available(iOS 17, *) {
            chatIdsOnHomescreen = UserDefaults.shared!
                .getChatWidgetEntries()
                .filter { $0.accountId == viewModel.context.id }
                .compactMap { entry in
                    switch entry.type {
                    case .app: return nil
                    case .chat(let chatId): return chatId
                    }
                }
        } else {
            chatIdsOnHomescreen = []
        }

        let isOnHomescreen = chatIdsOnHomescreen.contains(viewModel.chatId)
        cell.imageView?.image = UIImage(systemName: isOnHomescreen ? "minus.square" : "plus.square")
        cell.actionTitle = String.localized(isOnHomescreen ? "remove_from_widget" : "add_to_widget")
        return cell
    }()

    private lazy var shareContactCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.imageView?.image = UIImage(systemName: "square.and.arrow.up")
        cell.textLabel?.text = String.localized("menu_share")
        cell.textLabel?.textColor = UIColor.systemBlue
        return cell
    }()

    private lazy var ephemeralMessagesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("ephemeral_messages")
        cell.imageView?.image = UIImage(systemName: "stopwatch")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var showEncrInfoCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "info.circle")
        cell.actionTitle = String.localized("encryption_info_title_desktop")
        return cell
    }()

    private lazy var blockContactCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: "nosign")
        cell.actionTitle = viewModel.contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        cell.actionColor = UIColor.systemRed
        return cell
    }()

    private lazy var archiveChatCell: ActionCell = {
        let cell = ActionCell()
        cell.imageView?.image = UIImage(systemName: viewModel.chatIsArchived ? "tray.and.arrow.up" : "tray.and.arrow.down")
        cell.actionTitle = viewModel.chatIsArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
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

    private lazy var verifiedByCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.imageView?.image = UIImage(named: "verified")?.scaleDownImage(toMax: 24)
        return cell
    }()

    private lazy var allMediaCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("media")
        cell.imageView?.image = UIImage(systemName: "photo.on.rectangle")
        cell.accessoryType = .disclosureIndicator
        if viewModel.chatId == 0 {
            cell.isUserInteractionEnabled = false
            cell.textLabel?.isEnabled = false
        }
        return cell
    }()

    private lazy var locationsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("locations")
        cell.imageView?.image = UIImage(systemName: "map")
        cell.accessoryType = .disclosureIndicator
        if viewModel.chatId == 0 {
            cell.isUserInteractionEnabled = false
            cell.textLabel?.isEnabled = false
        }
        return cell
    }()

    private lazy var statusCell: MultilineLabelCell = {
        let cell = MultilineLabelCell()
        cell.multilineDelegate = self
        return cell
    }()

    init(dcContext: DcContext, contactId: Int) {
        self.viewModel = ContactDetailViewModel(dcContext: dcContext, contactId: contactId)
        super.init(style: .insetGrouped)

        NotificationCenter.default.addObserver(self, selector: #selector(ContactDetailViewController.handleContactsChanged(_:)), name: Event.contactsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ContactDetailViewController.handleIncomingMessage(_:)), name: Event.incomingMessage, object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        if !self.viewModel.isSavedMessages && !self.viewModel.isDeviceTalk {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: String.localized("global_menu_edit_desktop"),
                style: .plain, target: self, action: #selector(editButtonPressed))
            if self.viewModel.isBot {
                self.title = String.localized("bot")
            } else {
                self.title = String.localized("tab_contact")
            }
        } else {
            self.title = String.localized("profile")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeader() // maybe contact name has been edited
        updateCellValues()
        tableView.reloadData()

        // see comment in GroupChatDetailViewController.viewWillAppear()
        AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
    }

    // MARK: - setup and configuration
    private func configureTableView() {
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        headerCell.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        tableView.tableHeaderView = headerCell
        tableView.sectionHeaderHeight =  UITableView.automaticDimension
        tableView.rowHeight = UITableView.automaticDimension
    }

    // MARK: - UITableViewDatasource, UITableViewDelegate
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            headerCell.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let cellType = viewModel.typeFor(section: indexPath.section)
        switch cellType {
        case .chatOptions:
            switch viewModel.chatOptionFor(row: row) {
            case .verifiedBy:
                return verifiedByCell
            case .allMedia:
                return allMediaCell
            case .locations:
                return locationsCell
            case .ephemeralMessages:
                return ephemeralMessagesCell
            }
        case .statusArea:
            return statusCell
        case .startChatButtons:
            switch viewModel.startChatButtonFor(row: row) {
            case .startChat:
                return startChatCell
            case .shareContact:
                return shareContactCell
            }
        case .chatActions:
            switch viewModel.chatActionFor(row: row) {
            case .archiveChat:
                return archiveChatCell
            case .showEncrInfo:
                return showEncrInfoCell
            case .blockContact:
                return blockContactCell
            case .clearChat:
                return clearChatCell
            case .deleteChat:
                return deleteChatCell
            case .addToHomescreen:
                return homescreenWidgetCell
            }
        case .sharedChats:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell {
                viewModel.update(sharedChatCell: cell, row: row)
                cell.backgroundColor = DcColors.profileCellBackgroundColor
                return cell
            }
        }
        return UITableViewCell() // should never get here
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = viewModel.typeFor(section: indexPath.section)
        switch type {
        case .chatOptions:
            handleChatOption(indexPath: indexPath)
        case .statusArea:
            break
        case .startChatButtons:
            handleStartChatButton(indexPath: indexPath)
        case .chatActions:
            handleChatAction(indexPath: indexPath)
        case .sharedChats:
            let chatId = viewModel.getSharedChatIdAt(indexPath: indexPath)
            showChat(chatId: chatId)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let type = viewModel.typeFor(section: indexPath.section)
        switch type {
        case .sharedChats:
            return ContactCell.cellHeight
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.titleFor(section: section)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return viewModel.footerFor(section: section)
    }

    // MARK: - Notifications

    @objc private func handleContactsChanged(_ notification: Notification) {
        guard let ui = notification.userInfo,
              viewModel.contactId == ui["contact_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateHeader()
        }
    }
    
    @objc private func handleIncomingMessage(_ notification: Notification) {
        guard let ui = notification.userInfo,
              let chatId = ui["chat_id"] as? Int, viewModel.getSharedChatIds().contains(chatId) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            self.viewModel.updateSharedChats()
            if self.viewModel.chatId == chatId {
                self.updateCellValues()
            }
            self.tableView.reloadData()
        }
    }

    // MARK: - updates
    private func updateHeader() {
        if viewModel.isSavedMessages {
            let chat = viewModel.context.getChat(chatId: viewModel.chatId)
            headerCell.updateDetails(title: chat.name, subtitle: String.localized("chat_self_talk_subtitle"))
            if let img = chat.profileImage {
                headerCell.setImage(img)
            } else {
                headerCell.setBackupImage(name: chat.name, color: chat.color)
            }
            headerCell.setGreenCheckmark(greenCheckmark: false)
            headerCell.showMuteButton(show: false)
        } else {
            headerCell.updateDetails(title: viewModel.contact.displayName,
                                     subtitle: viewModel.isDeviceTalk ? String.localized("device_talk_subtitle") : viewModel.contact.email)
            if let img = viewModel.contact.profileImage {
                headerCell.setImage(img)
            } else {
                headerCell.setBackupImage(name: viewModel.contact.displayName, color: viewModel.contact.color)
            }
            headerCell.setGreenCheckmark(greenCheckmark: viewModel.greenCheckmark)
            headerCell.setMuted(isMuted: viewModel.chatIsMuted)
            headerCell.showMuteButton(show: true)
        }
        headerCell.showSearchButton(show: viewModel.chatCanSend)
    }

    private func updateCellValues() {
        ephemeralMessagesCell.detailTextLabel?.text = String.localized(viewModel.chatIsEphemeral ? "on" : "off")
        allMediaCell.detailTextLabel?.text = viewModel.chatId == 0 ? String.localized("none") : viewModel.context.getAllMediaCount(chatId: viewModel.chatId)
        statusCell.setText(text: viewModel.isSavedMessages ? String.localized("saved_messages_explain") : viewModel.contact.status)

        let verifierId = viewModel.contact.getVerifierId()
        if  verifierId != 0 {
            let verifiedInfo: String
            if verifierId == DC_CONTACT_ID_SELF {
                verifiedByCell.accessoryType = .none
                verifiedInfo = String.localized("verified_by_you")
            } else {
                verifiedByCell.accessoryType = .disclosureIndicator
                verifiedInfo = String.localizedStringWithFormat(String.localized("verified_by"),
                                                                viewModel.context.getContact(id: verifierId).displayName)
            }
            verifiedByCell.textLabel?.text = verifiedInfo
        }
    }

    // MARK: - actions
    @objc private func shareContact() {
        guard let vcardData = viewModel.context.makeVCard(contactIds: [viewModel.contactId]) else { return }

        RelayHelper.shared.setForwardVCard(dialogTitle: String.localized("forward_to"), vcardData: vcardData)
        navigationController?.popToRootViewController(animated: true)
    }

    @objc private func showCopyToClipboard() {
        UIMenuController.shared.menuItems = [
            UIMenuItem(title: String.localized("menu_copy_to_clipboard"), action: #selector(ContactDetailViewController.copyToClipboard))
        ]
        
        UIMenuController.shared.showMenu(from: headerCell.titleLabelContainer, rect: headerCell.titleLabelContainer.frame)
    }

    @objc private func copyToClipboard() {
        UIPasteboard.general.string = viewModel.contact.email
    }

    private func handleChatAction(indexPath: IndexPath) {
        let action = viewModel.chatActionFor(row: indexPath.row)
        switch action {
        case .archiveChat:
            tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
            toggleArchiveChat()
        case .showEncrInfo:
            tableView.deselectRow(at: indexPath, animated: false)
            showEncrInfoAlert()
        case .blockContact:
            tableView.deselectRow(at: indexPath, animated: false)
            toggleBlockContact()
        case .clearChat:
            tableView.deselectRow(at: indexPath, animated: false)
            showClearChatConfirmationAlert()
        case .deleteChat:
            tableView.deselectRow(at: indexPath, animated: false)
            showDeleteChatConfirmationAlert()
        case .addToHomescreen:
            tableView.deselectRow(at: indexPath, animated: true)
            toggleChatInHomescreenWidget()
        }
    }

    private func handleChatOption(indexPath: IndexPath) {
        let action = viewModel.chatOptionFor(row: indexPath.row)
        switch action {
        case .verifiedBy:
            tableView.deselectRow(at: indexPath, animated: true)
            let verifierId = viewModel.contact.getVerifierId()
            if verifierId != 0 && verifierId != DC_CONTACT_ID_SELF {
                showContact(contactId: verifierId)
            }
        case .allMedia:
            showAllMedia()
        case .locations:
            showLocations()
        case .ephemeralMessages:
            showEphemeralMessagesController()
        }
    }

    private func handleStartChatButton(indexPath: IndexPath) {
        let startChatButton = viewModel.startChatButtonFor(row: indexPath.row)
        switch startChatButton {
        case .startChat:
            tableView.deselectRow(at: indexPath, animated: false)
            let contactId = viewModel.contactId
            chatWith(contactId: contactId)
        case .shareContact:
            shareContact()
        }
    }

    private func toggleArchiveChat() {
        let archived = viewModel.toggleArchiveChat()
        if archived {
            self.navigationController?.popToRootViewController(animated: false)
        } else {
            archiveChatCell.imageView?.image = UIImage(systemName: "tray.and.arrow.down")
            archiveChatCell.actionTitle = String.localized("menu_archive_chat")
        }
    }

    private func toggleMuteChat() {
        if viewModel.chatIsMuted {
            self.viewModel.context.setChatMuteDuration(chatId: self.viewModel.chatId, duration: 0)
            headerCell.setMuted(isMuted: viewModel.chatIsMuted)
            self.navigationController?.popViewController(animated: true)
        } else {
            MuteDialog.show(viewController: self) { [weak self] duration in
                guard let self else { return }
                viewModel.context.setChatMuteDuration(chatId: viewModel.chatId, duration: duration)
                headerCell.setMuted(isMuted: viewModel.chatIsMuted)
                navigationController?.popViewController(animated: true)
            }
        }
    }

    private func toggleChatInHomescreenWidget() {
        guard #available(iOS 17, *) else { return }

        let onHomescreen = viewModel.toggleChatInHomescreenWidget()
        homescreenWidgetCell.imageView?.image = UIImage(systemName: onHomescreen ? "minus.square" : "plus.square")
        homescreenWidgetCell.actionTitle = String.localized(onHomescreen ? "remove_from_widget" : "add_to_widget")
    }

    private func updateBlockContactCell() {
        blockContactCell.actionTitle = viewModel.contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
    }


    @objc private func editButtonPressed() {
        showEditContact(contactId: viewModel.contactId)
    }

    // MARK: alerts

    private func showClearChatConfirmationAlert() {
        let msgIds = viewModel.context.getChatMsgs(chatId: viewModel.chatId, flags: 0)
        if !msgIds.isEmpty {
            let alert = UIAlertController(
                title: nil,
                message: String.localized(stringID: "ask_delete_messages_simple", parameter: msgIds.count),
                preferredStyle: .safeActionSheet
            )
            alert.addAction(UIAlertAction(title: String.localized("clear_chat"), style: .destructive, handler: { _ in
                self.viewModel.context.deleteMessages(msgIds: msgIds)
                if #available(iOS 17.0, *) {
                    msgIds.forEach { UserDefaults.shared?.removeWebxdcFromHomescreen(accountId: self.viewModel.context.id, messageId: $0) }
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
            message: String.localizedStringWithFormat(String.localized("ask_delete_named_chat"), viewModel.context.getChat(chatId: viewModel.chatId).name),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.deleteChat()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showEncrInfoAlert() {
        let alert = UIAlertController(
            title: nil,
            message: self.viewModel.context.getContactEncrInfo(contactId: self.viewModel.contactId),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showEphemeralMessagesController() {
        let ephemeralMessagesController = EphemeralMessagesViewController(dcContext: viewModel.context, chatId: viewModel.chatId)
        navigationController?.pushViewController(ephemeralMessagesController, animated: true)
    }

    private func toggleBlockContact() {
        if viewModel.contact.isBlocked {
            let alert = UIAlertController(title: String.localized("ask_unblock_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_unblock_contact"), style: .default, handler: { _ in
                self.viewModel.unblockContact()
                self.updateBlockContactCell()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String.localized("ask_block_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_block_contact"), style: .destructive, handler: { _ in
                self.viewModel.blockContact()
                self.updateBlockContactCell()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    private func chatWith(contactId: Int) {
        let chatId = self.viewModel.context.createChatByContactId(contactId: contactId)
        self.showChat(chatId: chatId)
    }

    // MARK: - coordinator
    private func showChat(chatId: Int) {
        if let chatlistViewController = navigationController?.viewControllers[0] as? ChatListViewController {
            let chatViewController = ChatViewController(dcContext: viewModel.context, chatId: chatId)
            chatlistViewController.backButtonUpdateableDataSource = chatViewController
            navigationController?.setViewControllers([chatlistViewController, chatViewController], animated: true)
        }
    }

    private func showContact(contactId: Int) {
        let contactViewController = ContactDetailViewController(dcContext: viewModel.context, contactId: contactId)
        navigationController?.pushViewController(contactViewController, animated: true)
    }

    private func showEditContact(contactId: Int) {
        let editContactController = EditContactController(dcContext: viewModel.context, contactIdForUpdate: contactId)
        navigationController?.pushViewController(editContactController, animated: true)
    }

    private func showAllMedia() {
        navigationController?.pushViewController(AllMediaViewController(dcContext: viewModel.context, chatId: viewModel.chatId), animated: true)
    }

    private func showLocations() {
        navigationController?.pushViewController(MapViewController(dcContext: viewModel.context, chatId: viewModel.chatId), animated: true)
    }

    private func showSearch() {
        if let chatViewController = navigationController?.viewControllers.last(where: {
            $0 is ChatViewController
        }) as? ChatViewController {
            chatViewController.activateSearchOnAppear()
            navigationController?.popViewController(animated: true)
        }
    }

    private func showContactAvatarIfNeeded() {
        if viewModel.isSavedMessages {
            let chat = viewModel.context.getChat(chatId: viewModel.chatId)
            if let url = chat.profileImageURL {
                let previewController = PreviewController(dcContext: viewModel.context, type: .single(url))
                previewController.customTitle = chat.name
                navigationController?.pushViewController(previewController, animated: true)
            }
        } else if let url = viewModel.contact.profileImageURL {
            let previewController = PreviewController(dcContext: viewModel.context, type: .single(url))
            previewController.customTitle = viewModel.contact.displayName
            navigationController?.pushViewController(previewController, animated: true)
        }
    }

    private func deleteChat() {
        if viewModel.chatId == 0 {
            return
        }
        viewModel.context.deleteChat(chatId: viewModel.chatId)
        if #available(iOS 17.0, *) {
            UserDefaults.shared?.removeChatFromHomescreenWidget(accountId: viewModel.context.id, chatId: viewModel.chatId)
        }
        NotificationManager.removeNotificationsForChat(dcContext: viewModel.context, chatId: viewModel.chatId)
        INInteraction.delete(with: ["\(viewModel.context.id).\(viewModel.chatId)"])

        navigationController?.popViewControllers(viewsToPop: 2, animated: true)
    }
}

extension ContactDetailViewController: MultilineLabelCellDelegate {
    func phoneNumberTapped(number: String) {
        let sanitizedNumber = number.filter("0123456789".contains)
        if let phoneURL = URL(string: "tel://\(sanitizedNumber)") {
            UIApplication.shared.open(phoneURL, options: [:], completionHandler: nil)
        }
    }

    func urlTapped(url: URL) {
        if Utils.isEmail(url: url) {
            let email = Utils.getEmailFrom(url)
            let contactId = viewModel.context.createContact(name: "", email: email)
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), email),
                                          message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { [weak self] _ in
                guard let self else { return }
                let chatId = self.viewModel.context.createChatByContactId(contactId: contactId)
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.appCoordinator.showChat(chatId: chatId, clearViewControllerStack: true)
                }
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else if Utils.isProxy(url: url, dcContext: viewModel.context),
                  let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let appCoordinator = appDelegate.appCoordinator {
            appCoordinator.handleProxySelection(on: self, dcContext: viewModel.context, proxyURL: url.absoluteString)
        } else if url.isDeltaChatInvitation,
                  let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                  let appCoordinator = appDelegate.appCoordinator {
            appCoordinator.handleDeltaChatInvitation(url: url, from: self)
        } else {
            UIApplication.shared.open(url)
        }
    }
}
