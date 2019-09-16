import UIKit

class GroupChatDetailViewController: UIViewController {
    private var currentUser: DcContact? {
        return groupMembers.filter { $0.email == DcConfig.addr }.first
    }

    weak var coordinator: GroupChatDetailCoordinator?

    fileprivate var chat: DcChat

    var chatDetailTable: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.bounces = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "tableCell")
        table.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
        table.register(ContactCell.self, forCellReuseIdentifier: "contactCell")

        return table
    }()

    init(chatId: Int) {
        chat = DcChat(id: chatId)
        super.init(nibName: nil, bundle: nil)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        view.addSubview(chatDetailTable)
        chatDetailTable.translatesAutoresizingMaskIntoConstraints = false

        chatDetailTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        chatDetailTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        chatDetailTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        chatDetailTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    private func showNotificationSetup() {
        let notificationSetupAlert = UIAlertController(title: "Notifications Setup is not implemented yet",
                                                       message: "But you get an idea where this is going",
                                                       preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil)
        notificationSetupAlert.addAction(cancelAction)
        present(notificationSetupAlert, animated: true, completion: nil)
    }

    private lazy var editBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: String.localized("global_menu_edit_desktop"), style: .plain, target: self, action: #selector(editButtonPressed))
    }()

    private var groupMembers: [DcContact] = []

    private let staticCellCountMemberSection = 1 //

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("tab_group")
        chatDetailTable.delegate = self
        chatDetailTable.dataSource = self
        navigationItem.rightBarButtonItem = editBarButtonItem
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateGroupMembers()
        chatDetailTable.reloadData() // to display updates
        editBarButtonItem.isEnabled = currentUser != nil
        NavBarUtils.setSmallTitle(navigationController: navigationController)
    }

    private func updateGroupMembers() {
        let ids = chat.contactIds
        groupMembers = ids.map { DcContact(id: $0) }
        chatDetailTable.reloadData()
    }

    @objc func editButtonPressed() {
        coordinator?.showGroupChatEdit(chat: chat)
    }

    private func leaveGroup() {
        if let userId = currentUser?.id {
            dc_remove_contact_from_chat(mailboxPointer, UInt32(chat.id), UInt32(userId))
            editBarButtonItem.isEnabled = false
            updateGroupMembers()
        }
    }
}

extension GroupChatDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return String.localized("tab_members")
        }
        return nil
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let header = ContactDetailHeader()
            header.updateDetails(title: chat.name, subtitle: chat.subtitle)
            if let img = chat.profileImage {
                header.setImage(img)
            } else {
                header.setBackupImage(name: chat.name, color: chat.color)
            }
            header.setVerified(isVerified: chat.isVerified)
            return header
        } else {
            return nil
        }
    }

    func numberOfSections(in _: UITableView) -> Int {
        /*
         section 0: config
         section 1: members
         section 2: leave group (optional - if user already left group this option will be hidden)
         */

        if currentUser == nil {
            return 2
        }
        return 3
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else if section == 1 {
            return groupMembers.count + staticCellCountMemberSection // first cell is addGroupMemberCell
        } else if section == 2 {
            return 1
        } else {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath)
            cell.textLabel?.text = String.localized("pref_notifications")
            cell.selectionStyle = .none
            return cell
        } else if section == 1 {
            if row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
                if let actionCell = cell as? ActionCell {
                    actionCell.actionTitle = String.localized("group_add_members")
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
                if let contactCell = cell as? ContactCell {
                    let contact = groupMembers[row - staticCellCountMemberSection]
                    let displayName = contact.displayName
                    contactCell.nameLabel.text = displayName
                    contactCell.emailLabel.text = contact.email
                    contactCell.initialsLabel.text = Utils.getInitials(inputName: displayName)
                    contactCell.setColor(contact.color)
                }
                return cell
            }
        } else if section == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            if let actionCell = cell as? ActionCell {
                actionCell.actionTitle = String.localized("menu_leave_group")
                actionCell.actionColor = UIColor.red
            }
            return cell
        }

        return UITableViewCell(frame: .zero)
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = indexPath.section
        let row = indexPath.row
        if section == 0 {
            showNotificationSetup()
        } else if section == 1 {
            if row == 0 {
                coordinator?.showAddGroupMember(chatId: chat.id)
            }
            // ignore for now - in Telegram tapping a contactCell leads into ContactDetail
        } else if section == 2 {
            leaveGroup()
        }
    }

    func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let section = indexPath.section
        let row = indexPath.row

        if let currentUser = currentUser {
            if section == 1, row > 0, groupMembers[row - staticCellCountMemberSection].id != currentUser.id {
                return true
            }
        }
        return false
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let section = indexPath.section
        let row = indexPath.row

        // assigning swipe by delete to members (except for current user)
        if section == 1, row >= staticCellCountMemberSection, groupMembers[row - staticCellCountMemberSection].id != currentUser?.id {
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("global_menu_edit_delete_desktop")) { [unowned self] _, indexPath in

                let memberId = self.groupMembers[row - self.staticCellCountMemberSection].id
                let success = dc_remove_contact_from_chat(mailboxPointer, UInt32(self.chat.id), UInt32(memberId))
                if success == 1 {
                    self.groupMembers.remove(at: row - self.staticCellCountMemberSection)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    tableView.reloadData()
                }
            }
            delete.backgroundColor = UIColor.red
            return [delete]
        } else {
            return nil
        }
    }
}
