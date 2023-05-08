import UIKit
import DcCore

class AddGroupMembersViewController: GroupMembersViewController {
    var onMembersSelected: ((Set<Int>) -> Void)?
    lazy var isVerifiedGroup: Bool = false
    private var isBroadcast: Bool = false

    private lazy var sections: [AddGroupMemberSections] = {
        if isVerifiedGroup {
            return [.memberList]
        } else {
            return [.newContact, .memberList]
        }
    }()

    enum AddGroupMemberSections {
        case newContact
        case memberList
    }

    private lazy var chatMemberIds: [Int] = {
        if let chat = chat {
            return chat.getContactIds(dcContext)
        }
        return []
    }()

    private lazy var chat: DcChat? = {
        if let chatId = self.chatId {
            return dcContext.getChat(chatId: chatId)
        }
        return nil
    }()

    private var chatId: Int?

    private lazy var newContactCell: ActionCell = {
        let cell = ActionCell()
        cell.actionColor = UIColor.systemBlue
        cell.actionTitle = String.localized("menu_new_contact")
        return cell
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

    lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
        return button
    }()

    // add members of new group, no chat object yet
    init(dcContext: DcContext, preselected: Set<Int>, isVerified: Bool, isBroadcast: Bool) {
        super.init(dcContext: dcContext)
        isVerifiedGroup = isVerified
        self.isBroadcast = isBroadcast
        numberOfSections = sections.count
        selectedContactIds = preselected
    }

    // add members of existing group
    init(dcContext: DcContext, chatId: Int) {
        self.chatId = chatId
        super.init(dcContext: dcContext)
        isVerifiedGroup = chat?.isProtected ?? false
        isBroadcast = chat?.isBroadcast ?? false
        numberOfSections = sections.count
        selectedContactIds = Set(dcContext.getChat(chatId: chatId).getContactIds(dcContext))
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized(isBroadcast ? "add_recipients" : "group_add_members")
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = cancelButton
        contactIds = loadMemberCandidates()
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc func doneButtonPressed() {
        if let onMembersSelected = onMembersSelected {
            onMembersSelected(selectedContactIds)
        }
        navigationController?.popViewController(animated: true)
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
            tableView.deselectRow(at: indexPath, animated: false)
            showNewContactController()
        case .memberList:
            didSelectContactCell(at: indexPath)
        }
    }

    func loadMemberCandidates() -> [Int] {
        var flags: Int32 = 0
        if isVerifiedGroup {
            flags |= DC_GCL_VERIFIED_ONLY
        }
        return dcContext.getContacts(flags: flags)
    }

    private func showNewContactController() {
        let newContactController = NewContactController(dcContext: dcContext, searchResult: searchText)
        newContactController.createChatOnSave = false
        newContactController.onContactSaved = { [weak self] (contactId: Int) -> Void in
            guard let self = self else { return }
            self.contactIds = self.loadMemberCandidates()
            if self.contactIds.contains(contactId) {
                self.selectedContactIds.insert(contactId)
                self.tableView.reloadData()
            }
        }
        navigationController?.pushViewController(newContactController, animated: true)
    }
    
    // MARK: - search
    override open func filterContactIds(flags: Int32, queryString: String) -> [Int] {
        let flags = self.isVerifiedGroup ? DC_GCL_VERIFIED_ONLY : DC_GCL_ADD_SELF
        return dcContext.getContacts(flags: flags, queryString: queryString)
    }
}
