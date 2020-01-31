import UIKit

// this is also used as ChatDetail for SingleChats
class ContactDetailViewController: UITableViewController {
    weak var coordinator: ContactDetailCoordinatorProtocol?
    private let viewModel: ContactDetailViewModelProtocol

    private lazy var startChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionColor = SystemColor.blue.uiColor
        cell.actionTitle = String.localized("menu_new_chat")
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
        tableView.reloadData()
    }

    // MARK: - setup and configuration
    private func configureTableView() {
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
    }

    // MARK: - UITableViewDatasource, UITableViewDelegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellType = viewModel.typeFor(section: indexPath.section)
        switch cellType {
        case .blockContact:
            return blockContactCell
        case .startChat:
            return startChatCell
        case .sharedChats:
            if let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell {
                viewModel.update(sharedChatCell: cell, row: indexPath.row)
                return cell
            }
        }
        return UITableViewCell() // should never get here

    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let type = viewModel.typeFor(section: indexPath.section)
        switch type {
        case .blockContact:
            toggleBlockContact()
        case .startChat:
            let contactId = viewModel.contactId
            askToChatWith(contactId: contactId)
        case .sharedChats:
            let chatId = viewModel.getSharedChatIdAt(indexPath: indexPath)
            coordinator?.showChat(chatId: chatId)
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return ContactDetailHeader.cellHeight
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let type = viewModel.typeFor(section: indexPath.section)
        switch type {
        case .blockContact, .startChat:
            return 44
        case .sharedChats:
            return ContactCell.cellHeight
        }
    }
    
    override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let header = ContactDetailHeader()
            let displayName = viewModel.contact.displayName
            header.updateDetails(title: displayName, subtitle: viewModel.contact.email)
            if let img = viewModel.contact.profileImage {
                header.setImage(img)
            } else {
                header.setBackupImage(name: displayName, color: viewModel.contact.color)
            }
            header.setVerified(isVerified: viewModel.contact.isVerified)
            return header
        }
        return nil
    }

    // MARK: -actions
    private func askToChatWith(contactId: Int) {
        let dcContact = DcContact(id: contactId)
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr),
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

    private func updateBlockContactCell() {
        blockContactCell.actionTitle = viewModel.contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        blockContactCell.actionColor = viewModel.contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
    }

    private func showNotificationSetup() {
        let notificationSetupAlert = UIAlertController(title: "Notifications Setup is not implemented yet",
                                                       message: "But you get an idea where this is going",
                                                       preferredStyle: .safeActionSheet)
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil)
        notificationSetupAlert.addAction(cancelAction)
        present(notificationSetupAlert, animated: true, completion: nil)
    }

    @objc private func editButtonPressed() {
        coordinator?.showEditContact(contactId: viewModel.contactId)
    }
}
