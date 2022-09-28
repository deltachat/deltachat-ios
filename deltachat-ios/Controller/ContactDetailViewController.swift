import UIKit
import DcCore
import Intents

// this is also used as ChatDetail for SingleChats
class ContactDetailViewController: UITableViewController {
    private let viewModel: ContactDetailViewModel

    private lazy var headerCell: ContactDetailHeader = {
        let headerCell = ContactDetailHeader()
        headerCell.showSearchButton(show: viewModel.chatId != 0)
        headerCell.onAvatarTap = showContactAvatarIfNeeded
        headerCell.onMuteButtonTapped = toggleMuteChat
        headerCell.onSearchButtonTapped = showSearch
        headerCell.setRecentlySeen(viewModel.contact.wasSeenRecently)
        return headerCell
    }()


    private lazy var startChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionColor = SystemColor.blue.uiColor
        cell.actionTitle = String.localized("send_message")
        return cell
    }()

    private lazy var ephemeralMessagesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("ephemeral_messages")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var showEncrInfoCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("encryption_info_title_desktop")
        cell.actionColor = SystemColor.blue.uiColor
        return cell
    }()

    private lazy var copyToClipboardCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_copy_to_clipboard")
        cell.actionColor = SystemColor.blue.uiColor
        return cell
    }()

    private lazy var blockContactCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = viewModel.contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        cell.actionColor = viewModel.contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
        return cell
    }()

    private lazy var archiveChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = viewModel.chatIsArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        cell.actionColor = SystemColor.blue.uiColor
        return cell
    }()

    private lazy var deleteChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_delete_chat")
        cell.actionColor = UIColor.red
        return cell
    }()

    private lazy var galleryCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("images_and_videos")
        cell.accessoryType = .disclosureIndicator
        if viewModel.chatId == 0 {
            cell.isUserInteractionEnabled = false
            cell.textLabel?.isEnabled = false
        }
        return cell
    }()

    private lazy var documentsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("files_and_webxdx_apps")
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

    private var incomingMsgsObserver: NSObjectProtocol?
    private var contactChangedObserver: NSObjectProtocol?

    init(dcContext: DcContext, contactId: Int) {
        self.viewModel = ContactDetailViewModel(dcContext: dcContext, contactId: contactId)
        super.init(style: .grouped)
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
            self.title = String.localized("tab_contact")
        } else {
            self.title = String.localized("profile")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupObservers()
        updateHeader() // maybe contact name has been edited
        updateCellValues()
        tableView.reloadData()

        // see comment in GroupChatDetailViewController.viewWillAppear()
        AppDelegate.emitMsgsChangedIfShareExtensionWasUsed()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeObservers()
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
            case .documents:
                return documentsCell
            case .gallery:
                return galleryCell
            case .ephemeralMessages:
                return ephemeralMessagesCell
            case .startChat:
                return startChatCell
            }
        case .statusArea:
            return statusCell
        case .chatActions:
            switch viewModel.chatActionFor(row: row) {
            case .archiveChat:
                return archiveChatCell
            case .showEncrInfo:
                return showEncrInfoCell
            case .copyToClipboard:
                return copyToClipboardCell
            case .blockContact:
                return blockContactCell
            case .deleteChat:
                return deleteChatCell
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
        case .chatActions:
            handleChatAction(indexPath: indexPath)
        case .sharedChats:
            let chatId = viewModel.getSharedChatIdAt(indexPath: indexPath)
            showChat(chatId: chatId)
        }
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

    // MARK: - observers
    private func setupObservers() {
        let nc = NotificationCenter.default
        contactChangedObserver = nc.addObserver(
            forName: dcNotificationContactChanged,
            object: nil,
            queue: OperationQueue.main) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo,
               self.viewModel.contactId == ui["contact_id"] as? Int {
                self.updateHeader()
            }
        }
        incomingMsgsObserver = nc.addObserver(
            forName: dcNotificationIncoming,
            object: nil,
            queue: OperationQueue.main) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo,
               let chatId = ui["chat_id"] as? Int {
                if self.viewModel.getSharedChatIds().contains(chatId) {
                    self.viewModel.updateSharedChats()
                    if self.viewModel.chatId == chatId {
                        self.updateCellValues()
                    }
                    self.tableView.reloadData()
                }
            }
        }
    }

    private func removeObservers() {
        let nc = NotificationCenter.default
        if let contactChangedObserver = self.contactChangedObserver {
            nc.removeObserver(contactChangedObserver)
        }
        if let incomingMsgsObserver = self.incomingMsgsObserver {
            nc.removeObserver(incomingMsgsObserver)
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
            headerCell.setVerified(isVerified: false)
            headerCell.showMuteButton(show: false)
        } else {
            headerCell.updateDetails(title: viewModel.contact.displayName,
                                     subtitle: viewModel.isDeviceTalk ? String.localized("device_talk_subtitle") : viewModel.contact.email)
            if let img = viewModel.contact.profileImage {
                headerCell.setImage(img)
            } else {
                headerCell.setBackupImage(name: viewModel.contact.displayName, color: viewModel.contact.color)
            }
            headerCell.setVerified(isVerified: viewModel.contact.isVerified)
            headerCell.setMuted(isMuted: viewModel.chatIsMuted)
            headerCell.showMuteButton(show: true)
        }
    }

    private func updateCellValues() {
        ephemeralMessagesCell.detailTextLabel?.text = String.localized(viewModel.chatIsEphemeral ? "on" : "off")
        galleryCell.detailTextLabel?.text = String.numberOrNone(viewModel.galleryItemMessageIds.count)
        documentsCell.detailTextLabel?.text = String.numberOrNone(viewModel.documentItemMessageIds.count)
        statusCell.setText(text: viewModel.contact.status)
    }

    // MARK: - actions
    private func handleChatAction(indexPath: IndexPath) {
        let action = viewModel.chatActionFor(row: indexPath.row)
        switch action {
        case .archiveChat:
            tableView.deselectRow(at: indexPath, animated: true) // animated as no other elements pop up
            toggleArchiveChat()
        case .showEncrInfo:
            tableView.deselectRow(at: indexPath, animated: false)
            showEncrInfoAlert()
        case .copyToClipboard:
            tableView.deselectRow(at: indexPath, animated: true)
            let pasteboard = UIPasteboard.general
            pasteboard.string = viewModel.contact.email
        case .blockContact:
            tableView.deselectRow(at: indexPath, animated: false)
            toggleBlockContact()
        case .deleteChat:
            tableView.deselectRow(at: indexPath, animated: false)
            showDeleteChatConfirmationAlert()
        }
    }

    private func handleChatOption(indexPath: IndexPath) {
        let action = viewModel.chatOptionFor(row: indexPath.row)
        switch action {
        case .documents:
            showDocuments()
        case .gallery:
            showGallery()
        case .ephemeralMessages:
            showEphemeralMessagesController()
        case .startChat:
            tableView.deselectRow(at: indexPath, animated: false)
            let contactId = viewModel.contactId
            chatWith(contactId: contactId)
        }
    }

    private func toggleArchiveChat() {
        let archived = viewModel.toggleArchiveChat()
        if archived {
            self.navigationController?.popToRootViewController(animated: false)
        } else {
            archiveChatCell.actionTitle = String.localized("menu_archive_chat")
        }
    }

    private func toggleMuteChat() {
        if viewModel.chatIsMuted {
            self.viewModel.context.setChatMuteDuration(chatId: self.viewModel.chatId, duration: 0)
            headerCell.setMuted(isMuted: viewModel.chatIsMuted)
            self.navigationController?.popViewController(animated: true)
        } else {
            showMuteAlert()
        }
    }

    private func updateBlockContactCell() {
        blockContactCell.actionTitle = viewModel.contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        blockContactCell.actionColor = viewModel.contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
    }


    @objc private func editButtonPressed() {
        showEditContact(contactId: viewModel.contactId)
    }

    // MARK: alerts

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
        let ephemeralMessagesController = SettingsEphemeralMessageController(dcContext: viewModel.context, chatId: viewModel.chatId)
        navigationController?.pushViewController(ephemeralMessagesController, animated: true)
    }

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
            self.viewModel.context.setChatMuteDuration(chatId: self.viewModel.chatId, duration: duration)
            self.headerCell.setMuted(isMuted: self.viewModel.chatIsMuted)
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(action)
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
        if let chatlistViewController = navigationController?.viewControllers[0] {
            let chatViewController = ChatViewController(dcContext: viewModel.context, chatId: chatId)
            navigationController?.setViewControllers([chatlistViewController, chatViewController], animated: true)
        }
    }

    private func showEditContact(contactId: Int) {
        let editContactController = EditContactController(dcContext: viewModel.context, contactIdForUpdate: contactId)
        navigationController?.pushViewController(editContactController, animated: true)
    }

    private func showDocuments() {
        let messageIds: [Int] = viewModel.documentItemMessageIds.reversed()
        let fileGalleryController = DocumentGalleryController(context: viewModel.context, chatId: viewModel.chatId, fileMessageIds: messageIds)
        navigationController?.pushViewController(fileGalleryController, animated: true)
    }

    private func showGallery() {
        let messageIds: [Int] = viewModel.galleryItemMessageIds.reversed()
        let galleryController = GalleryViewController(context: viewModel.context, chatId: viewModel.chatId, mediaMessageIds: messageIds)
        navigationController?.pushViewController(galleryController, animated: true)
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
                guard let self = self else { return }
                let chatId = self.viewModel.context.createChatByContactId(contactId: contactId)
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.appCoordinator.showChat(chatId: chatId, clearViewControllerStack: true)
                }
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            UIApplication.shared.open(url)
        }
    }
}
