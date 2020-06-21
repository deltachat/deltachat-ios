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

    lazy var doneButton: UIBarButtonItem = {
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
            return getNumberOfRowsForContactList()
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case sectionNewContact:
            return Constants.defaultCellHeight
        case sectionMemberList:
            return ContactCell.cellHeight
        default:
            return Constants.defaultCellHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case sectionNewContact:
            return getNewContactCell()
        case sectionMemberList:
            return getContactCell(cellForRowAt: indexPath)
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
        var contactIds = dcContext.getContacts(flags: 0)
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

    func getNewContactCell() -> UITableViewCell {
        let cell: UITableViewCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "actionCell") {
            cell = c
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: "actionCell")
        }
        cell.textLabel?.text = String.localized("menu_new_contact")
        cell.textLabel?.textColor = view.tintColor
        cell.textLabel?.textAlignment = .center

        return cell
    }

    // MARK: - coordinator
    private func showNewContactController() {
        let newContactController = NewContactController(dcContext: dcContext)
        newContactController.openChatOnSave = false
        navigationController?.pushViewController(newContactController, animated: true)
    }
}
