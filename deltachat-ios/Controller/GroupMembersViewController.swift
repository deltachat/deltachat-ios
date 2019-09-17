import UIKit

class NewGroupViewController: GroupMembersViewController {
    weak var coordinator: NewGroupCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_new_group")
        let groupCreationNextButton = UIBarButtonItem(title: String.localized("next"),
                                                      style: .done,
                                                      target: self,
                                                      action: #selector(nextButtonPressed))
        navigationItem.rightBarButtonItem = groupCreationNextButton
        contactIds = Utils.getContactIds()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NavBarUtils.setSmallTitle(navigationController: navigationController)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @objc func nextButtonPressed() {
        coordinator?.showGroupNameController(contactIdsForGroup: selectedContactIds)
    }
}

class AddGroupMembersViewController: GroupMembersViewController {
    private var chatId: Int?

    private lazy var resetButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("reset"), style: .plain, target: self, action: #selector(resetButtonPressed))
        button.isEnabled = false
        return button
    }()

    override var selectedContactIds: Set<Int> {
        didSet {
            resetButton.isEnabled = !selectedContactIds.isEmpty
        }
    }

    private lazy var chat: DcChat? = {
        if let chatId = chatId {
            return DcChat(id: chatId)
        }
        return nil
    }()

    private lazy var chatMemberIds: [Int] = {
        if let chat = chat {
            return chat.contactIds
        }
        return []
    }()

    private lazy var memberCandidateIds: [Int] = {
        var contactIds = Set(Utils.getContactIds()) // turn into set to speed up search
        for member in chatMemberIds {
            contactIds.remove(member)
        }
        return Array(contactIds)
    }()

    init(chatId: Int) {
        super.init()
        self.chatId = chatId
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        super.contactIds = memberCandidateIds
        super.navigationItem.rightBarButtonItem = resetButton
        title = String.localized("group_add_members")
        // Do any additional setup after loading the view.
    }

    override func viewWillDisappear(_: Bool) {
        guard let chatId = chatId else {
            return
        }
        for contactId in selectedContactIds {
            dc_add_contact_to_chat(mailboxPointer, UInt32(chatId), UInt32(contactId))
        }
    }

    @objc func resetButtonPressed() {
        selectedContactIds = []
        tableView.reloadData()
    }
}

class GroupMembersViewController: UITableViewController, UISearchResultsUpdating {
    let contactCellReuseIdentifier = "contactCell"

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
    
    var selectedContactIds: Set<Int> = []

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return isFiltering() ? filteredContacts.count : contacts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell: ContactCell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ContactCell else {
            fatalError("shouldn't happen")
        }

        let row = indexPath.row
        let contact: ContactWithSearchResults = contactSearchResultByRow(row)
        updateContactCell(cell: cell, contactWithHighlight: contact)
        cell.accessoryType = selectedContactIds.contains(contactIdByRow(row)) ? .checkmark : .none

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if let cell = tableView.cellForRow(at: indexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            let contactId = contactIdByRow(row)
            if selectedContactIds.contains(contactId) {
                selectedContactIds.remove(contactId)
                cell.accessoryType = .none
            } else {
                selectedContactIds.insert(contactId)
                cell.accessoryType = .checkmark
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
    }

    private func updateContactCell(cell: ContactCell, contactWithHighlight: ContactWithSearchResults) {
        let contact = contactWithHighlight.contact
        let displayName = contact.displayName

        let emailLabelFontSize = cell.emailLabel.font.pointSize
        let nameLabelFontSize = cell.nameLabel.font.pointSize

        cell.initialsLabel.text = Utils.getInitials(inputName: displayName)
        cell.setColor(contact.color)
        cell.setVerified(isVerified: contact.isVerified)

        if let emailHighlightedIndexes = contactWithHighlight.indexesToHighlight.filter({ $0.contactDetail == .EMAIL }).first {
            // gets here when contact is a result of current search -> highlights relevant indexes
            cell.emailLabel.attributedText = contact.email.boldAt(indexes: emailHighlightedIndexes.indexes, fontSize: emailLabelFontSize)
        } else {
            cell.emailLabel.attributedText = contact.email.boldAt(indexes: [], fontSize: emailLabelFontSize)
        }

        if let nameHighlightedIndexes = contactWithHighlight.indexesToHighlight.filter({ $0.contactDetail == .NAME }).first {
            cell.nameLabel.attributedText = displayName.boldAt(indexes: nameHighlightedIndexes.indexes, fontSize: nameLabelFontSize)
        } else {
            cell.nameLabel.attributedText = displayName.boldAt(indexes: [], fontSize: nameLabelFontSize)
        }
    }

 

    
}
