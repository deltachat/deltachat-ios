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

    private let chat: DcChat?

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
    init(dcContext: DcContext, preselected: Set<Int>, isBroadcast: Bool) {
        self.chat = nil
        super.init(dcContext: dcContext)
        isVerifiedGroup = false
        self.isBroadcast = isBroadcast
        numberOfSections = sections.count
        selectedContactIds = preselected
    }

    // add members of existing group
    init(dcContext: DcContext, chatId: Int) {
        self.chat = dcContext.getChat(chatId: chatId)
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
            didSelectContactCell(at: indexPath, verifiedContactRequired: isVerifiedGroup)
        }
    }

    func loadMemberCandidates() -> [Int] {
        return dcContext.getContacts(flags: DC_GCL_ADD_SELF)
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
    override open func filterContactIds(queryString: String) -> [Int] {
        return dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: queryString)
    }
}
