import UIKit

// this is also used as ChatDetail for SingleChats
class ContactDetailViewController: UITableViewController {
    weak var coordinator: ContactDetailCoordinatorProtocol?
    private let viewModel: ContactDetailViewModelProtocol

    let sectionOptions = 0
    let sectionOptionsRowStartChat = 1
    let sectionOptionsRowCount = 1

    let sectionBlockContact = 1
    let sectionBlockContactRowCount = 1

    let sectionCount = 2

    var showStartChat = true

    var optionCells: [UITableViewCell] = []

    private let contactId: Int

    private var contact: DcContact {
        return DcContact(id: contactId)
    }

    private lazy var startChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionColor = SystemColor.blue.uiColor
        cell.actionTitle = String.localized("menu_new_chat")
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var blockContactCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        cell.actionColor = contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
        cell.selectionStyle = .none
        return cell
    }()

    init(viewModel: ContactDetailViewModelProtocol) {
        self.viewModel = viewModel
        self.contactId = viewModel.contactId
        super.init(style: .grouped)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String.localized("global_menu_edit_desktop"),
            style: .plain, target: self, action: #selector(editButtonPressed))
        self.title = String.localized("tab_contact")
        if showStartChat {
            optionCells.append(startChatCell)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == sectionOptions {
            return optionCells.count
        } else if section == sectionBlockContact {
            return sectionBlockContactRowCount
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        if section == sectionOptions {
            return startChatCell
        } else {
            return blockContactCell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = indexPath.section
        if section == sectionOptions {
            askToChatWith(contactId: contactId)
        } else {
            toggleBlockContact()
        }
    }

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

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return ContactDetailHeader.cellHeight
        }
        return 0
    }
    
    override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let header = ContactDetailHeader()
            let displayName = contact.displayName
            header.updateDetails(title: displayName, subtitle: contact.email)
            if let img = contact.profileImage {
                header.setImage(img)
            } else {
                header.setBackupImage(name: displayName, color: contact.color)
            }
            header.setVerified(isVerified: contact.isVerified)
            return header
        }
        return nil
    }

    private func toggleBlockContact() {
        if contact.isBlocked {
            let alert = UIAlertController(title: String.localized("ask_unblock_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_unblock_contact"), style: .default, handler: { _ in
                self.contact.unblock()
                self.updateBlockContactCell()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String.localized("ask_block_contact"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_block_contact"), style: .destructive, handler: { _ in
                self.contact.block()
                self.updateBlockContactCell()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }

    private func updateBlockContactCell() {
        blockContactCell.actionTitle = contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        blockContactCell.actionColor = contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
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
        coordinator?.showEditContact(contactId: contactId)
    }
}
