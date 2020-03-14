import UIKit

// this is also used as ChatDetail for SingleChats
class ContactDetailViewController: UITableViewController {
    weak var coordinator: ContactDetailCoordinatorProtocol?
    private let viewModel: ContactDetailViewModelProtocol

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
        return cell
    }()

    private lazy var documentsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("documents")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()


    init(viewModel: ContactDetailViewModelProtocol) {
        self.viewModel = viewModel
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
            case .archiveChat:
                return archiveChatCell
            case .blockChat:
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
            askToChatWith(contactId: contactId)
        case .sharedChats:
            let chatId = viewModel.getSharedChatIdAt(indexPath: indexPath)
            coordinator?.showChat(chatId: chatId)
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
    }

    // MARK: - actions
    private func handleCellAction(for index: Int) {
        let action = viewModel.chatActionFor(row: index)
        switch action {
        case .archiveChat:
            toggleArchiveChat()
        case .blockChat:
            toggleBlockContact()
        case .deleteChat:
            showDeleteChatConfirmationAlert()
        }
    }

    private func handleAttachmentAction(for index: Int) {
        let action = viewModel.attachmentActionFor(row: index)
        switch action {
        case .documents:
            coordinator?.showDocuments()
        case .gallery:
            coordinator?.showGallery()
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
        coordinator?.showEditContact(contactId: viewModel.contactId)
    }
}

// MARK: alerts
extension ContactDetailViewController {
    private func showDeleteChatConfirmationAlert() {
        let alert = UIAlertController(
            title: nil,
            message: String.localized("ask_delete_chat_desktop"),
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_delete_chat"), style: .destructive, handler: { _ in
            self.coordinator?.deleteChat()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    private func showNotificationSetup() {
        let notificationSetupAlert = UIAlertController(
            title: "Notifications Setup is not implemented yet",
            message: "But you get an idea where this is going",
            preferredStyle: .safeActionSheet)
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil)
        notificationSetupAlert.addAction(cancelAction)
        present(notificationSetupAlert, animated: true, completion: nil)
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

    private func askToChatWith(contactId: Int) {
        let dcContact = DcContact(id: contactId)
        let alert = UIAlertController(title: String.localizedStringWithFormat(
            String.localized("ask_start_chat_with"), dcContact.nameNAddr),
                                      message: nil,
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            let chatId = Int(dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId)))
            self.coordinator?.showChat(chatId: chatId)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

}
