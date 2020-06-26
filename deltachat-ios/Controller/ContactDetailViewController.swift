import UIKit
import DcCore

// this is also used as ChatDetail for SingleChats
class ContactDetailViewController: UITableViewController {
    private let viewModel: ContactDetailViewModel

    private lazy var headerCell: ContactDetailHeader = {
        let cell = ContactDetailHeader()
        cell.updateDetails(title: viewModel.contact.displayName, subtitle: viewModel.contact.email)
        if let img = viewModel.contact.profileImage {
            cell.setImage(img)
        } else {
            cell.setBackupImage(name: viewModel.contact.displayName, color: viewModel.contact.color)
        }
        cell.setVerified(isVerified: viewModel.contact.isVerified)
        return cell
    }()

    private lazy var startChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionColor = SystemColor.blue.uiColor
        cell.actionTitle = String.localized("send_message")
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var blockContactCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = viewModel.contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        cell.actionColor = viewModel.contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var muteChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = viewModel.chatIsMuted ? String.localized("menu_unmute") :  String.localized("menu_mute")
        cell.actionColor = SystemColor.blue.uiColor
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var archiveChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = viewModel.chatIsArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        cell.actionColor = SystemColor.blue.uiColor
        cell.selectionStyle = .none
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
        if viewModel.chatId == 0 {
            cell.isUserInteractionEnabled = false
            cell.textLabel?.isEnabled = false
        }
        return cell
    }()

    private lazy var documentsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("documents")
        cell.accessoryType = .disclosureIndicator
        if viewModel.chatId == 0 {
            cell.isUserInteractionEnabled = false
            cell.textLabel?.isEnabled = false
        }
        return cell
    }()


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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String.localized("global_menu_edit_desktop"),
            style: .plain, target: self, action: #selector(editButtonPressed))
        self.title = String.localized("tab_contact")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeader() // maybe contact name has been edited
        tableView.reloadData()
    }

    // MARK: - setup and configuration
    private func configureTableView() {
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        headerCell.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
        tableView.tableHeaderView = headerCell
    }

    // MARK: - UITableViewDatasource, UITableViewDelegate

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
        case .attachments:
            switch viewModel.attachmentActionFor(row: row) {
            case .documents:
                return documentsCell
            case .gallery:
                return galleryCell
            }
        case .chatActions:
            switch viewModel.chatActionFor(row: row) {
            case .muteChat:
                return muteChatCell
            case .archiveChat:
                return archiveChatCell
            case .blockContact:
                return blockContactCell
            case .deleteChat:
                return deleteChatCell
            }
        case .startChat:
            return startChatCell
        case .sharedChats:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell {
                viewModel.update(sharedChatCell: cell, row: row)
                return cell
            }
        }
        return UITableViewCell() // should never get here
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = viewModel.typeFor(section: indexPath.section)
        switch type {
        case .attachments:
            handleAttachmentAction(for: indexPath.row)
        case .chatActions:
            handleCellAction(for: indexPath.row)
        case .startChat:
            let contactId = viewModel.contactId
            chatWith(contactId: contactId)
        case .sharedChats:
            let chatId = viewModel.getSharedChatIdAt(indexPath: indexPath)
            showChat(chatId: chatId)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let type = viewModel.typeFor(section: indexPath.section)
        switch type {
        case .chatActions, .startChat, .attachments:
            return Constants.defaultCellHeight
        case .sharedChats:
            return ContactCell.cellHeight
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return viewModel.titleFor(section: section)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Constants.defaultHeaderHeight
    }

    // MARK: - updates
    private func updateHeader() {
        headerCell.updateDetails(title: viewModel.contact.displayName, subtitle: viewModel.contact.email)
        if let img = viewModel.contact.profileImage {
            headerCell.setImage(img)
        } else {
            headerCell.setBackupImage(name: viewModel.contact.displayName, color: viewModel.contact.color)
        }
        headerCell.setVerified(isVerified: viewModel.contact.isVerified)
    }

    // MARK: - actions
    private func handleCellAction(for index: Int) {
        let action = viewModel.chatActionFor(row: index)
        switch action {
        case .muteChat:
            if viewModel.chatIsMuted {
                self.viewModel.context.setChatMuteDuration(chatId: self.viewModel.chatId, duration: 0)
                muteChatCell.actionTitle = String.localized("menu_mute")
            } else {
                showMuteAlert()
            }
        case .archiveChat:
            toggleArchiveChat()
        case .blockContact:
            toggleBlockContact()
        case .deleteChat:
            showDeleteChatConfirmationAlert()
        }
    }

    private func handleAttachmentAction(for index: Int) {
        let action = viewModel.attachmentActionFor(row: index)
        switch action {
        case .documents:
            showDocuments()
        case .gallery:
            showGallery()
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
            message: String.localized("ask_delete_chat_desktop"),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.deleteChat()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showMuteAlert() {
        let alert = UIAlertController(title: String.localized("mute"), message: nil, preferredStyle: .safeActionSheet)
        let forever = -1
        addDurationSelectionAction(to: alert, key: "mute_for_one_hour", duration: Time.oneHour)
        addDurationSelectionAction(to: alert, key: "mute_for_one_hour", duration: Time.twoHours)
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
            self.muteChatCell.actionTitle = String.localized("menu_unmute")
        })
        alert.addAction(action)
    }

    private func toggleBlockContact() {
        if viewModel.contact.isBlocked {
            let alert = UIAlertController(title: String.localized("ask_unblock_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_unblock_contact"), style: .default, handler: { _ in
                self.viewModel.contact.unblock()
                self.updateBlockContactCell()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String.localized("ask_block_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_block_contact"), style: .destructive, handler: { _ in
                self.viewModel.contact.block()
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
        let messageIds = viewModel.context.getChatMedia(
            chatId: viewModel.chatId,
            messageType: DC_MSG_FILE,
            messageType2: DC_MSG_AUDIO,
            messageType3: 0
        )
        let fileGalleryController = DocumentGalleryController(fileMessageIds: messageIds)
        navigationController?.pushViewController(fileGalleryController, animated: true)
    }

    private func showGallery() {
        let messageIds = viewModel.context.getChatMedia(
            chatId: viewModel.chatId,
            messageType: DC_MSG_IMAGE,
            messageType2: DC_MSG_GIF,
            messageType3: DC_MSG_VIDEO
        )
        let galleryController = GalleryViewController(mediaMessageIds: messageIds)
            navigationController?.pushViewController(galleryController, animated: true)
    }

    private func deleteChat() {
        if viewModel.chatId == 0 {
            return
        }
        viewModel.context.deleteChat(chatId: viewModel.chatId)

        // just pop to viewControllers - we've in chatlist or archive then
        // (no not use `navigationController?` here: popping self will make the reference becoming nil)
        if let navigationController = navigationController {
            navigationController.popViewController(animated: false)
            navigationController.popViewController(animated: true)
        }
    }
}
