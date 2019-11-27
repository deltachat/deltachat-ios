import UIKit

class GroupChatDetailViewController: UIViewController {

    private let sectionMembers = 0
    private let sectionMembersRowAddMember = 0
    private let sectionMembersRowJoinQR = 1
    private let sectionMembersStaticRowCount = 2 // followed by one row per member

    private let sectionLeaveGroup = 1
    private let sectionLeaveGroupRowCount = 1

    private let sectionCount = 2

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

    private lazy var editBarButtonItem: UIBarButtonItem = {
        UIBarButtonItem(title: String.localized("global_menu_edit_desktop"), style: .plain, target: self, action: #selector(editButtonPressed))
    }()

    private var groupMembers: [DcContact] = []

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
        //update chat object, maybe chat name was edited
        chat = DcChat(id: chat.id)
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
            let alert = UIAlertController(title: String.localized("ask_leave_group"), message: nil, preferredStyle: .actionSheet)
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

extension GroupChatDetailViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == sectionMembers {
            return ContactDetailHeader.cellHeight
        }
        return 0
    }
    
    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == sectionMembers {
            let header = ContactDetailHeader()
            header.updateDetails(title: chat.name,
                                 subtitle: String.localizedStringWithFormat(String.localized("n_members"), chat.contactIds.count))
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
        if currentUser == nil {
            return sectionCount-1 // leave out last section (leaveSection)
        }
        return sectionCount
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case sectionMembers:
            return sectionMembersStaticRowCount + groupMembers.count
        case sectionLeaveGroup:
            return sectionLeaveGroupRowCount
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = indexPath.section
        let row = indexPath.row
        switch section {
        case sectionMembers:
            switch row {
            case sectionMembersRowAddMember:
                return Constants.defaultCellHeight
            case sectionMembersRowJoinQR:
                return Constants.defaultCellHeight
            default:
                return ContactCell.cellHeight
            }
        case sectionLeaveGroup:
            return Constants.defaultCellHeight
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
                    contactCell.nameLabel.text = displayName
                    contactCell.emailLabel.text = contact.email
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
        let section = indexPath.section
        let row = indexPath.row

        if let currentUser = currentUser {
            if section == sectionMembers, row >= sectionMembersStaticRowCount, groupMembers[row - sectionMembersStaticRowCount].id != currentUser.id {
                return true
            }
        }
        return false
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let section = indexPath.section
        let row = indexPath.row

        // assigning swipe by delete to members (except for current user)
        if section == sectionMembers, row >= sectionMembersStaticRowCount, groupMembers[row - sectionMembersStaticRowCount].id != currentUser?.id {
            let delete = UITableViewRowAction(style: .destructive, title: String.localized("remove_desktop")) { [unowned self] _, indexPath in

                let contact = self.getGroupMember(at: row)
                let title = String.localizedStringWithFormat(String.localized("ask_remove_members"), contact.nameNAddr)
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: String.localized("remove_desktop"), style: .destructive, handler: { _ in
                    let success = dc_remove_contact_from_chat(mailboxPointer, UInt32(self.chat.id), UInt32(contact.id))
                    if success == 1 {
                        self.groupMembers.remove(at: row - self.sectionMembersStaticRowCount)
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
    }

    func getGroupMember(at row: Int) -> DcContact {
        let memberId = self.groupMembers[row - self.sectionMembersStaticRowCount].id
        return DcContact(id: memberId)
    }

}
