import UIKit

// this is also used as ChatDetail for SingleChats
class ContactDetailViewController: UITableViewController {
    weak var coordinator: ContactDetailCoordinatorProtocol?
    let sectionOptions = 0
    let sectionBlockContact = 1
    let sectionOptionsRowNotifications = 0
    var showStartChat = true
    var optionCells: [UITableViewCell] = []

    private enum CellIdentifiers: String {
        case notification = "notificationCell"
        case block = "blockContactCell"
        case chat = "chatCell"
    }

    private let contactId: Int

    private var contact: DcContact {
        return DcContact(id: contactId)
    }

    private var notificationsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_notifications")
        cell.accessibilityIdentifier = CellIdentifiers.notification.rawValue
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        cell.selectionStyle = .none
        // TODO: add current notification status
        return cell
    }()

    private lazy var chatCell: ActionCell = {
        let cell = ActionCell()
        cell.accessibilityIdentifier = CellIdentifiers.chat.rawValue
        cell.actionColor = SystemColor.blue.uiColor
        cell.actionTitle = String.localized("menu_new_chat")
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var blockContactCell: ActionCell = {
        let cell = ActionCell()
        cell.accessibilityIdentifier = CellIdentifiers.block.rawValue
        cell.actionTitle = contact.isBlocked ? String.localized("menu_unblock_contact") : String.localized("menu_block_contact")
        cell.actionColor = contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
        cell.selectionStyle = .none
        return cell
    }()

    init(contactId: Int) {
        self.contactId = contactId
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
        optionCells.insert(notificationsCell, at: 0)
        if showStartChat {
            optionCells.insert(chatCell, at: 1)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == sectionOptions {
            return optionCells.count
        } else if section == sectionBlockContact {
            return 1
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if section == sectionOptions {
            if row == sectionOptionsRowNotifications {
                return notificationsCell
            } else {
                return chatCell
            }
        } else {
            return blockContactCell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }

        if let identifier = CellIdentifiers(rawValue: cell.accessibilityIdentifier ?? "") {
            switch identifier {
            case .block:
                toggleBlockContact()
            case .chat:
                askToChatWith(contactId: contactId)
            case .notification:
                showNotificationSetup()
            }
        }
    }

    private func askToChatWith(contactId: Int) {
        let dcContact = DcContact(id: contactId)
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr),
                                      message: nil,
                                      preferredStyle: .actionSheet)
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
            let alert = UIAlertController(title: String.localized("ask_unblock_contact"), message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_unblock_contact"), style: .default, handler: { _ in
                self.contact.unblock()
                self.updateBlockContactCell()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: String.localized("ask_block_contact"), message: nil, preferredStyle: .actionSheet)
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
                                                       preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil)
        notificationSetupAlert.addAction(cancelAction)
        present(notificationSetupAlert, animated: true, completion: nil)
    }

    @objc private func editButtonPressed() {
        coordinator?.showEditContact(contactId: contactId)
    }
}
