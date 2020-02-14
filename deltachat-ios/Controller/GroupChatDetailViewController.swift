import UIKit

class GroupChatDetailViewController: UIViewController {

    enum ProfileSections {
        case memberManagement // add member, qr invideCode
        case members // contactCells
        case chatActions // archive, leave, delete
    }

    weak var coordinator: GroupChatDetailCoordinator?

    let sections: [ProfileSections] = [.memberManagement, .members, .chatActions]

    private let sectionMembers = 0
    private let sectionMembersRowAddMember = 0
    private let sectionMembersRowJoinQR = 1
    private let sectionMembersStaticRowCount = 2 // followed by one row per member

    private let sectionLeaveGroup = 1
    private let sectionLeaveGroupRowCount = 1

    private let sectionCount = 2

    private var currentUser: DcContact? {
        let myId = groupMemberIds.filter { DcContact(id: $0).email == DcConfig.addr }.first
        guard let currentUserId = myId else {
            return nil
        }
        return DcContact(id: currentUserId)
    }

    fileprivate var chat: DcChat

    // MARK: -subviews
    lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .grouped)
        table.bounces = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "tableCell")
        table.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
        table.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        table.delegate = self
        table.dataSource = self
        table.tableHeaderView = headerCell
        return table
    }()

    private lazy var headerCell: ContactDetailHeader = {
        let header = ContactDetailHeader()
        header.updateDetails(
            title: chat.name,
            subtitle: String.localizedStringWithFormat(String.localized("n_members"), chat.contactIds.count)
        )
        if let img = chat.profileImage {
            header.setImage(img)
        } else {
            header.setBackupImage(name: chat.name, color: chat.color)
        }
        header.setVerified(isVerified: chat.isVerified)
        return header
    }()

    private lazy var archiveChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = chat.isArchived ? String.localized("menu_unarchive_chat") :  String.localized("menu_archive_chat")
        cell.actionColor = SystemColor.blue.uiColor
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var leaveGroupCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_leave_group")
        cell.actionColor = UIColor.red
        return cell
    }()


    private lazy var deleteChatCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("menu_delete_chat")
        cell.actionColor = UIColor.red
        cell.selectionStyle = .none
        return cell
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
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    private lazy var editBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: String.localized("global_menu_edit_desktop"), style: .plain, target: self, action: #selector(editButtonPressed))
    }()

    // stores contactIds
    private var groupMemberIds: [Int] = []

    // MARK: -lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("tab_group")
        navigationItem.rightBarButtonItem = editBarButtonItem
        headerCell.frame = CGRect(0, 0, tableView.frame.width, ContactCell.cellHeight)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateGroupMembers()
        tableView.reloadData() // to display updates
        editBarButtonItem.isEnabled = currentUser != nil
        //update chat object, maybe chat name was edited
        chat = DcChat(id: chat.id)
    }

    // MARK: -update
    private func updateGroupMembers() {
        groupMemberIds = chat.contactIds
        tableView.reloadData()
    }

    // MARK: -actions
    @objc func editButtonPressed() {
        coordinator?.showGroupChatEdit(chat: chat)
    }

    private func leaveGroup() {
        if let userId = currentUser?.id {
            let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_leave_group"), style: .destructive, handler: { _ in
                dc_remove_contact_from_chat(mailboxPointer, UInt32(self.chat.id), UInt32(userId))
                self.editBarButtonItem.isEnabled = false
                self.updateGroupMembers()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: -UITableViewDelegate, UITableViewDataSource
extension GroupChatDetailViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == sectionMembers {
            return ContactDetailHeader.cellHeight
        }
        return 0
    }

    func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionType = sections[section]
        switch sectionType {
        case .memberManagement:
            return 2
        case .members:
            return groupMemberIds.count
        case .chatActions:
            return 3
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionType = sections[indexPath.section]
        switch sectionType {
        case .memberManagement:
            return Constants.defaultCellHeight
        case .members:
            return ContactCell.cellHeight
        case .chatActions:
            return Constants.defaultCellHeight
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        switch sectionType {
        case .memberManagement:
            guard let actionCell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath) as? ActionCell else {
                safe_fatalError("could not dequeu action cell")
                break
            }
            if row == 0 {
                actionCell.actionTitle = String.localized("group_add_members")
                actionCell.actionColor = UIColor.systemBlue

            } else {
                actionCell.actionTitle = String.localized("qrshow_join_group_title")
                actionCell.actionColor = UIColor.systemBlue

            }
            return actionCell
        case .members:
            guard let contactCell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath) as? ContactCell else {
                safe_fatalError("could not dequeu contactCell cell")
                break

            }
            let cellData = ContactCellData(contactId: groupMemberIds[row])
            let cellViewModel = ContactCellViewModel(contactData: cellData)
            contactCell.updateCell(cellViewModel: cellViewModel)
            return contactCell
        case .chatActions:
            if row == 0 {
                return archiveChatCell
            } else if row == 1 {
                return leaveGroupCell
            } else if row == 2 {
                return deleteChatCell
            }
        }
        // should never get here
        return UITableViewCell(frame: .zero)
        /*
         let section = indexPath.section
         let row = indexPath.row
         switch section {
         case sectionMembers:
         switch row {
         case sectionMembersRowAddMember:
         let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
         if let actionCell = cell as? ActionCell {
         actionCell.actionTitle = String.localized("group_add_members")
         actionCell.actionColor = UIColor.systemBlue
         }
         return cell
         case sectionMembersRowJoinQR:
         let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
         if let actionCell = cell as? ActionCell {
         actionCell.actionTitle = String.localized("qrshow_join_group_title")
         actionCell.actionColor = UIColor.systemBlue
         }
         return cell
         default:
         let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
         if let contactCell = cell as? ContactCell {
         let contact = groupMembers[row - sectionMembersStaticRowCount]
         let displayName = contact.displayName
         contactCell.titleLabel.text = displayName
         contactCell.subtitleLabel.text = contact.email
         contactCell.avatar.setName(displayName)
         contactCell.avatar.setColor(contact.color)
         if let profileImage = contact.profileImage {
         contactCell.avatar.setImage(profileImage)
         }
         contactCell.setVerified(isVerified: contact.isVerified)
         }
         return cell
         }
         case sectionLeaveGroup:
         let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
         if let actionCell = cell as? ActionCell {
         actionCell.actionTitle = String.localized("menu_leave_group")
         actionCell.actionColor = UIColor.red
         }
         return cell
         default:
         return UITableViewCell(frame: .zero)
         }
         */
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = indexPath.section
        let row = indexPath.row
        if section == sectionMembers {
            if row == sectionMembersRowAddMember {
                coordinator?.showAddGroupMember(chatId: chat.id)
            } else if row == sectionMembersRowJoinQR {
                coordinator?.showQrCodeInvite(chatId: chat.id)
            } else {
                let contact = getGroupMember(at: row)
                coordinator?.showContactDetail(of: contact.id)
            }
        } else if section == sectionLeaveGroup {
            leaveGroup()
        }
    }

    func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let currentUser = self.currentUser else {
            return false
        }
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        if sectionType == .members && groupMemberIds[row] != currentUser.id {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard let currentUser = self.currentUser else {
            return nil
        }
        let row = indexPath.row
        let sectionType = sections[indexPath.section]
        if sectionType == .members && groupMemberIds[row] != currentUser.id {
            // action set for members except for current user
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [unowned self] _, indexPath in

                let contact = self.getGroupMember(at: row)
                let title = String.localizedStringWithFormat(String.localized("ask_remove_members"), contact.nameNAddr)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("remove_desktop"), style: .destructive, handler: { _ in
                    let success = dc_remove_contact_from_chat(mailboxPointer, UInt32(self.chat.id), UInt32(contact.id))
                    if success == 1 {
                        self.groupMemberIds.remove(at: row)
                        tableView.deleteRows(at: [indexPath], with: .fade)
                        tableView.reloadData()
                    }
                }))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            delete.backgroundColor = UIColor.red
            return [delete]
        }
        return nil

        /*


        // assigning swipe by delete to members (except for current user)
        if section == sectionMembers, row >= sectionMembersStaticRowCount, groupMembers[row - sectionMembersStaticRowCount].id != currentUser?.id {
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [unowned self] _, indexPath in

                let contact = self.getGroupMember(at: row)
                let title = String.localizedStringWithFormat(String.localized("ask_remove_members"), contact.nameNAddr)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("remove_desktop"), style: .destructive, handler: { _ in
                    let success = dc_remove_contact_from_chat(mailboxPointer, UInt32(self.chat.id), UInt32(contact.id))
                    if success == 1 {
                        self.groupMemberIds.remove(at: row - self.sectionMembersStaticRowCount)
                        tableView.deleteRows(at: [indexPath], with: .fade)
                        tableView.reloadData()
                    }
                }))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            delete.backgroundColor = UIColor.red
            return [delete]
        } else {
            return nil
        }
        */
    }

    func getGroupMember(at row: Int) -> DcContact {
        return DcContact(id: groupMemberIds[row])
    }

}
