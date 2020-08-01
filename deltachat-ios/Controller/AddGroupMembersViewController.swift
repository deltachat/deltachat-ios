import UIKit
import DcCore

class AddGroupMembersViewController: GroupMembersViewController {
    private var chatId: Int?
    private let sectionNewContact = 0
    private let sectionMemberList = 1

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
        if let chatId = chatId {
            return dcContext.getChat(chatId: chatId)
        }
        return nil
    }()

    private lazy var chatMemberIds: [Int] = {
        if let chat = chat {
            return chat.contactIds
        }
        return []
    }()

    init(chatId: Int) {
        super.init()
        self.chatId = chatId
        numberOfSections = 2
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
        switch section {
        case sectionNewContact:
            return 1
        case sectionMemberList:
            return numberOfRowsForContactList
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == sectionMemberList ? ContactCell.cellHeight : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case sectionNewContact:
            return newContactCell
        case sectionMemberList:
            return updateContactCell(for: indexPath)
        default:
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case sectionNewContact:
            tableView.deselectRow(at: indexPath, animated: true)
            showNewContactController()
        case sectionMemberList:
            didSelectContactCell(at: indexPath)
        default:
            fatalError("unexpected section selected in GroupMembersViewController")
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
        guard let chatId = chatId else {
            return
        }
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
