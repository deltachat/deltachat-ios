import UIKit
import DcCore

class AddGroupMembersViewController: GroupMembersViewController {
    private var chatId: Int

    private lazy var sections: [AddGroupMemberSections] = {
        if let chat = self.chat, chat.isVerified {
            return [.memberList]
        } else {
            return [.newContact, .memberList]
        }
    }()

    enum AddGroupMemberSections {
        case newContact
        case memberList
    }

    private var contactAddedObserver: NSObjectProtocol?

    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    private lazy var newContactCell: ActionCell = {
        let cell = ActionCell()
        cell.actionColor = SystemColor.blue.uiColor
        cell.actionTitle = String.localized("menu_new_contact")
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
        return button
    }()

    private lazy var chat: DcChat? = {
        return dcContext.getChat(chatId: chatId)
    }()

    private lazy var chatMemberIds: [Int] = {
        if let chat = chat {
            return chat.contactIds
        }
        return []
    }()

    init(chatId: Int) {
        self.chatId = chatId
        super.init()
        numberOfSections = sections.count
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        super.navigationItem.leftBarButtonItem = cancelButton
        super.navigationItem.rightBarButtonItem = doneButton
        title = String.localized("group_add_members")
        super.contactIds = loadMemberCandidates()
        // Do any additional setup after loading the view.
        let nc = NotificationCenter.default
        contactAddedObserver = nc.addObserver(
            forName: dcNotificationContactChanged,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self = self else { return }
            if let ui = notification.userInfo {
                if let contactId = ui["contact_id"] as? Int {
                    if contactId == 0 {
                        return
                    }
                    self.contactIds = self.loadMemberCandidates()
                    if self.contactIds.contains(contactId) {
                        self.selectedContactIds.insert(contactId)
                        self.tableView.reloadData()
                    }

                }
            }
        }
    }

    override func viewWillDisappear(_: Bool) {
        if !isMovingFromParent {
            // a subview was added to the navigation stack, no action needed
            return
        }

        let nc = NotificationCenter.default
        if let observer = self.contactAddedObserver {
            nc.removeObserver(observer)
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionType = sections[section]
        switch sectionType {
        case .newContact:
            return 1
        case .memberList:
            return numberOfRowsForContactList
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let sectionType = sections[indexPath.section]
        return sectionType == .memberList ? ContactCell.cellHeight : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionType = sections[indexPath.section]
        switch sectionType {
        case .newContact:
            return newContactCell
        case .memberList:
            return updateContactCell(for: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sectionType = sections[indexPath.section]
        switch sectionType {
        case .newContact:
            tableView.deselectRow(at: indexPath, animated: true)
            showNewContactController()
        case .memberList:
            didSelectContactCell(at: indexPath)
        }
    }

    func loadMemberCandidates() -> [Int] {
        var flags: Int32 = 0
        if let chat = chat, chat.isVerified {
            flags |= DC_GCL_VERIFIED_ONLY
        }
        var contactIds = dcContext.getContacts(flags: flags)
        let memberSet = Set(chatMemberIds)
        contactIds.removeAll(where: { memberSet.contains($0)})
        return Array(contactIds)
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc func doneButtonPressed() {
        for contactId in selectedContactIds {
           _ = dcContext.addContactToChat(chatId: chatId, contactId: contactId)
        }
        navigationController?.popViewController(animated: true)
    }

    // MARK: - coordinator
    private func showNewContactController() {
        let newContactController = NewContactController(dcContext: dcContext)
        newContactController.openChatOnSave = false
        navigationController?.pushViewController(newContactController, animated: true)
    }
}
