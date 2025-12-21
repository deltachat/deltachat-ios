import UIKit
import DcCore

class AddGroupMembersViewController: GroupMembersViewController {
    var onMembersSelected: ((Set<Int>) -> Void)?
    private let gclFlags: Int32
    private let sections: [AddGroupMemberSections]

    enum AddGroupMemberSections {
        case newContact
        case memberList
    }

    private let chat: DcChat?

    private lazy var newContactCell: ActionCell = {
        let cell = ActionCell()
        cell.actionColor = UIColor.systemBlue
        cell.imageView?.image = UIImage(systemName: "highlighter")
        cell.actionTitle = String.localized("menu_new_classic_contact")
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
    init(dcContext: DcContext, preselected: Set<Int>, createMode: NewGroupController.CreateMode) {
        self.chat = nil
        self.gclFlags = DC_GCL_ADD_SELF | (createMode == .createEmail ? DC_GCL_ADDRESS : 0)
        self.sections = createMode == .createEmail ? [.newContact, .memberList] : [.memberList]
        super.init(dcContext: dcContext)
        numberOfSections = sections.count
        selectedContactIds = preselected
    }

    // add members of existing group
    init(dcContext: DcContext, chatId: Int) {
        self.chat = dcContext.getChat(chatId: chatId)
        self.gclFlags = DC_GCL_ADD_SELF
        self.sections = [.memberList]
        super.init(dcContext: dcContext)
        numberOfSections = sections.count
        selectedContactIds = Set(dcContext.getChat(chatId: chatId).getContactIds(dcContext))
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("group_add_members")
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
        return dcContext.getContacts(flags: gclFlags)
    }

    private func showNewContactController() {
        let newContactController = NewContactController(dcContext: dcContext, createChatOnSave: false, searchResult: searchText)
        newContactController.onContactSaved = { [weak self] contactId in
            guard let self else { return }
            self.contactIds = self.loadMemberCandidates()
            if !self.selectedContactIds.contains(contactId) {
                self.selectedContactIds.insert(contactId)
                self.tableView.reloadData()
            }
        }
        navigationController?.pushViewController(newContactController, animated: true)
    }
    
    // MARK: - search
    override open func filterContactIds(queryString: String) -> [Int] {
        return dcContext.getContacts(flags: gclFlags, queryString: queryString)
    }
}
