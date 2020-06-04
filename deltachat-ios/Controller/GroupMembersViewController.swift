import UIKit
import DcCore

class NewGroupAddMembersViewController: GroupMembersViewController {
    var onMembersSelected: ((Set<Int>) -> Void)?
    let isVerifiedGroup: Bool

    private lazy var cancelButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        return button
    }()

   lazy var doneButton: UIBarButtonItem = {
       let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
       return button
   }()

    init(preselected: Set<Int>, isVerified: Bool) {
        isVerifiedGroup = isVerified
        super.init()
        selectedContactIds = preselected
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("group_add_members")
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = cancelButton
        contactIds = isVerifiedGroup ?
            dcContext.getContacts(flags: DC_GCL_VERIFIED_ONLY) :
            dcContext.getContacts(flags: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    @objc func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc func doneButtonPressed() {
        if let onMembersSelected = onMembersSelected {
            selectedContactIds.insert(Int(DC_CONTACT_ID_SELF))
            onMembersSelected(selectedContactIds)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

}

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

class BlockedContactsViewController: GroupMembersViewController, GroupMemberSelectionDelegate {

    var emptyStateView: EmptyStateLabel = {
        let view =  EmptyStateLabel()
        view.text = String.localized("none_blocked_desktop")
        return view
    }()

    override init() {
        super.init()
        enableCheckmarks = false
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_blocked_contacts")
        contactIds = dcContext.getBlockedContacts()
        selectedContactIds = Set(contactIds)
        navigationItem.searchController = nil
        groupMemberSelectionDelegate = self
        setupSubviews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateEmtpyStateView()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        emptyStateView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
        emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40).isActive = true
        emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40).isActive = true
    }

    // MARK: - actions + updates
    func selected(contactId: Int, selected: Bool) {
        if !selected {
            let dcContact = DcContact(id: contactId)
            let title = dcContact.displayName.isEmpty ? dcContact.email : dcContact.displayName
            let alert = UIAlertController(title: title, message: String.localized("ask_unblock_contact"), preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_unblock_contact"), style: .default, handler: { _ in
                let contact = DcContact(id: contactId)
                contact.unblock()
                self.contactIds = self.dcContext.getBlockedContacts()
                self.selectedContactIds = Set(self.contactIds)
                self.tableView.reloadData()
                self.updateEmtpyStateView()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
                self.selectedContactIds = Set(self.contactIds)
                self.tableView.reloadData()
            }))
           present(alert, animated: true, completion: nil)
        }
    }

    private func updateEmtpyStateView() {
        emptyStateView.isHidden = super.getNumberOfRowsForContactList() > 0
    }
}

protocol GroupMemberSelectionDelegate: class {
    func selected(contactId: Int, selected: Bool)
}

class GroupMembersViewController: UITableViewController, UISearchResultsUpdating {
    let contactCellReuseIdentifier = "contactCell"
    weak var groupMemberSelectionDelegate: GroupMemberSelectionDelegate?
    var enableCheckmarks = true
    var numberOfSections = 1
    let dcContext: DcContext

    var contactIds: [Int] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    // contactWithSearchResults.indexesToHightLight empty by default
    var contacts: [ContactWithSearchResults] {
        return contactIds.map { ContactWithSearchResults(contact: DcContact(id: $0), indexesToHighlight: []) }
    }

    // used when seachbar is active
    var filteredContacts: [ContactWithSearchResults] = []

    // searchBar active?
    func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }

    private func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    private func contactIdByRow(_ row: Int) -> Int {
        return isFiltering() ? filteredContacts[row].contact.id : contactIds[row]
    }

    private func contactSearchResultByRow(_ row: Int) -> ContactWithSearchResults {
        return isFiltering() ? filteredContacts[row] : contacts[row]
    }

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.hidesNavigationBarDuringPresentation = false
        return searchController
    }()

    private lazy var emptySearchStateLabel: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.isHidden = true
        return label
    }()

    var selectedContactIds: Set<Int> = []

    init() {
        self.dcContext = DcContext.shared
        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        navigationItem.searchController = searchController
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        definesPresentationContext = true
        setupSubviews()
    }

    private func setupSubviews() {
        view.addSubview(emptySearchStateLabel)
        emptySearchStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptySearchStateLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        emptySearchStateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40).isActive = true
        emptySearchStateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40).isActive = true
        emptySearchStateLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
    }

    // MARK: - UITableView datasource + delegate
    override func numberOfSections(in _: UITableView) -> Int {
        return numberOfSections
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return getNumberOfRowsForContactList()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ContactCell.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return getContactCell(cellForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectContactCell(at: indexPath)
    }

    func getNumberOfRowsForContactList() -> Int {
        return isFiltering() ? filteredContacts.count : contacts.count
    }

    func getContactCell(cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell: ContactCell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ContactCell else {
            fatalError("shouldn't happen")
        }

        let row = indexPath.row
        let contact: ContactWithSearchResults = contactSearchResultByRow(row)
        updateContactCell(cell: cell, contactWithHighlight: contact)
        cell.accessoryType = selectedContactIds.contains(contactIdByRow(row)) && enableCheckmarks ? .checkmark : .none

        return cell
    }

    func didSelectContactCell(at indexPath: IndexPath) {
        let row = indexPath.row
        if let cell = tableView.cellForRow(at: indexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            let contactId = contactIdByRow(row)
            if selectedContactIds.contains(contactId) {
                selectedContactIds.remove(contactId)
                if enableCheckmarks {
                    cell.accessoryType = .none
                }
                groupMemberSelectionDelegate?.selected(contactId: contactId, selected: false)
            } else {
                selectedContactIds.insert(contactId)
                if enableCheckmarks {
                    cell.accessoryType = .checkmark
                }
                groupMemberSelectionDelegate?.selected(contactId: contactId, selected: true)
            }
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            filterContentForSearchText(searchText)
        } 
    }

    private func filterContentForSearchText(_ searchText: String, scope _: String = String.localized("pref_show_emails_all")) {
        let contactsWithHighlights: [ContactWithSearchResults] = contacts.map { contact in
            let indexes = contact.contact.containsExact(searchText: searchText)
            return ContactWithSearchResults(contact: contact.contact, indexesToHighlight: indexes)
        }

        filteredContacts = contactsWithHighlights.filter { !$0.indexesToHighlight.isEmpty }
        tableView.reloadData()
        tableView.scrollToTop()

        // handle empty searchstate
        if isFiltering() && getNumberOfRowsForContactList() == 0 {
            let text = String.localizedStringWithFormat(
                String.localized("search_no_result_for_x"),
                searchText
            )
            emptySearchStateLabel.text = text
            emptySearchStateLabel.isHidden = false
        } else {
            emptySearchStateLabel.text = nil
            emptySearchStateLabel.isHidden = true
        }
    }

    private func updateContactCell(cell: ContactCell, contactWithHighlight: ContactWithSearchResults) {
        let contact = contactWithHighlight.contact
        let displayName = contact.displayName

        let emailLabelFontSize = cell.subtitleLabel.font.pointSize
        let nameLabelFontSize = cell.titleLabel.font.pointSize

        cell.titleLabel.text = displayName
        cell.subtitleLabel.text = contact.email
        cell.avatar.setName(displayName)
        cell.avatar.setColor(contact.color)
        if let profileImage = contact.profileImage {
            cell.avatar.setImage(profileImage)
        }
        cell.setVerified(isVerified: contact.isVerified)

        if let emailHighlightedIndexes = contactWithHighlight.indexesToHighlight.filter({ $0.contactDetail == .EMAIL }).first {
            // gets here when contact is a result of current search -> highlights relevant indexes
            cell.subtitleLabel.attributedText = contact.email.boldAt(indexes: emailHighlightedIndexes.indexes, fontSize: emailLabelFontSize)
        } else {
            cell.subtitleLabel.attributedText = contact.email.boldAt(indexes: [], fontSize: emailLabelFontSize)
        }

        if let nameHighlightedIndexes = contactWithHighlight.indexesToHighlight.filter({ $0.contactDetail == .NAME }).first {
            cell.titleLabel.attributedText = displayName.boldAt(indexes: nameHighlightedIndexes.indexes, fontSize: nameLabelFontSize)
        } else {
            cell.titleLabel.attributedText = displayName.boldAt(indexes: [], fontSize: nameLabelFontSize)
        }
    }

}
