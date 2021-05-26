import Contacts
import UIKit
import DcCore

class NewChatViewController: UITableViewController {
    private let dcContext: DcContext

    private let sectionNew = 0
    private let sectionNewRowNewContact = 0
    private let sectionNewRowNewGroup = 1
    private let sectionNewRowNewVerifiedGroup = 2
    private let sectionNewRowCount = 3

    private let sectionImportedContacts = 1

    private var sectionContacts: Int { return deviceContactAccessGranted ? 1 : 2 }

    private var sectionsCount: Int { return deviceContactAccessGranted ? 2 : 3 }

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        return searchController
    }()

    private lazy var emptySearchStateLabel: EmptyStateLabel = {
        let label = EmptyStateLabel()
        label.isHidden = true
        return label
    }()

    private lazy var emptySearchStateLabelWidthConstraint: NSLayoutConstraint? = {
        return emptySearchStateLabel.widthAnchor.constraint(equalTo: tableView.widthAnchor)
    }()

    private var contactIds: [Int]
    private var filteredContactIds: [Int] = []

    private var searchText: String? {
        return searchController.searchBar.text
    }

    // searchBar active?
    var isFiltering: Bool {
        return !searchBarIsEmpty
    }

    private var searchBarIsEmpty: Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    lazy var deviceContactHandler: DeviceContactsHandler = {
        let handler = DeviceContactsHandler(dcContext: DcContext.shared)
        handler.contactListDelegate = self
        return handler
    }()

    var deviceContactAccessGranted: Bool = false {
        didSet {
            tableView.reloadData()
        }
    }

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        self.contactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF)
        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = String.localized("menu_new_chat")

        deviceContactHandler.importDeviceContacts()
        navigationItem.searchController = searchController
        definesPresentationContext = true // to make sure searchbar will only be shown in this viewController
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        tableView.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
        tableView.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
        tableView.sectionHeaderHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        deviceContactAccessGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    // MARK: - actions
    @objc func cancelButtonPressed() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Table view data source
    override func numberOfSections(in _: UITableView) -> Int {
        return sectionsCount
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == sectionNew {
            return sectionNewRowCount
        } else if section == sectionImportedContacts {
            if deviceContactAccessGranted {
                return isFiltering ? filteredContactIds.count : contactIds.count
            } else {
                return 1
            }
        } else {
            return isFiltering ? filteredContactIds.count : contactIds.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = indexPath.section
        if section == sectionNew {
            return UITableView.automaticDimension
        } else if section == sectionImportedContacts {
            if deviceContactAccessGranted {
                return ContactCell.cellHeight
            } else {
                return UITableView.automaticDimension
            }
        } else {
            return ContactCell.cellHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if section == sectionNew {
            let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
            if let actionCell = cell as? ActionCell {
                switch row {
                case sectionNewRowNewGroup:
                    actionCell.actionTitle = String.localized("menu_new_group")
                case sectionNewRowNewVerifiedGroup:
                    actionCell.actionTitle = String.localized("menu_new_verified_group")
                default:
                    actionCell.actionTitle = String.localized("menu_new_contact")
                }
            }
            return cell
        } else if section == sectionImportedContacts {
            // import device contacts section
            if deviceContactAccessGranted {
                let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
                if let contactCell = cell as? ContactCell {
                    let contactCellViewModel = self.contactViewModelBy(row: indexPath.row)
                    contactCell.updateCell(cellViewModel: contactCellViewModel)
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)
                if let actionCell = cell as? ActionCell {
                    actionCell.actionTitle = String.localized("import_contacts")
                }
                return cell
            }
        } else {
            // section contact list if device contacts are not imported
            let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath)
            if let contactCell = cell as? ContactCell {
                let contactCellViewModel = self.contactViewModelBy(row: indexPath.row)
                contactCell.updateCell(cellViewModel: contactCellViewModel)
            }
            return cell
        }
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        let section = indexPath.section

        if section == sectionNew {
            if row == sectionNewRowNewGroup {
                showNewGroupController(isVerified: false)
            } else if row == sectionNewRowNewVerifiedGroup {
                showNewGroupController(isVerified: true)
            } else if row == sectionNewRowNewContact {
                showNewContactController()
            }
        } else if section == sectionImportedContacts {
            if deviceContactAccessGranted {
                showChatAt(row: row)
            } else {
                showSettingsAlert()
            }
        } else {
            showChatAt(row: row)
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.section == sectionContacts {
            let contactId = contactIdByRow(indexPath.row)

            let edit = UITableViewRowAction(style: .normal, title: String.localized("info")) { [weak self] _, _ in
                guard let self = self else { return }
                if self.searchController.isActive {
                    self.searchController.dismiss(animated: false) {
                        self.showContactDetail(contactId: contactId)
                    }
                } else {
                    self.showContactDetail(contactId: contactId)
                }
            }

            let delete = UITableViewRowAction(style: .destructive, title: String.localized("delete")) { [weak self] _, _ in
                guard let self = self else { return }
                let contactId = self.contactIdByRow(indexPath.row)
                self.askToDeleteContact(contactId: contactId, indexPath: indexPath)
            }

            edit.backgroundColor = DcColors.primary
            return [edit, delete]
        } else {
            return []
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    private func contactIdByRow(_ row: Int) -> Int {
        return isFiltering ? filteredContactIds[row] : contactIds[row]
    }

    private func contactViewModelBy(row: Int) -> ContactCellViewModel {
        let id = contactIdByRow(row)
        return ContactCellViewModel.make(contactId: id, searchText: searchText, dcContext: dcContext)
    }

    // MARK: - updates
    private func deleteContact(contactId: Int, indexPath: IndexPath) {
        if dcContext.deleteContact(contactId: contactId) {
            contactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF)
            if isFiltering {
                filteredContactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: searchText)
            }
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }


    // MARK: - search
    private func reactivateSearchBarIfNeeded() {
        if !searchBarIsEmpty {
            searchController.isActive = true
        }
    }

    private func showChatAt(row: Int) {
        if searchController.isActive {
            // edge case: when searchController is active but searchBar is empty -> filteredContacts is empty, so we fallback to contactIds
            let contactId = contactIdByRow(row)
            searchController.dismiss(animated: false, completion: {
                self.askToChatWith(contactId: contactId)
            })
        } else {
            let contactId = contactIds[row]
            self.askToChatWith(contactId: contactId)
        }
    }

    private func filterContentForSearchText(_ searchText: String, scope _: String = String.localized("pref_show_emails_all")) {
        filteredContactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: searchText)
        tableView.reloadData()
        tableView.scrollToTop()

        // handle empty searchstate
        if searchController.isActive && filteredContactIds.isEmpty {
            let text = String.localizedStringWithFormat(
                String.localized("search_no_result_for_x"),
                searchText
            )
            emptySearchStateLabel.text = text
            emptySearchStateLabel.isHidden = false
            tableView.tableHeaderView = emptySearchStateLabel
            emptySearchStateLabelWidthConstraint?.isActive = true
        } else {
            emptySearchStateLabel.text = nil
            emptySearchStateLabel.isHidden = true
            emptySearchStateLabelWidthConstraint?.isActive = false
            tableView.tableHeaderView = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // ensure the empty search state message can be fully read
        if searchController.isActive && filteredContactIds.isEmpty {
            tableView.scrollRectToVisible(emptySearchStateLabel.frame, animated: false)
        }
    }

    // MARK: - coordinator
    private func showNewGroupController(isVerified: Bool) {
        let newGroupController = NewGroupController(dcContext: dcContext, isVerified: isVerified)
        navigationController?.pushViewController(newGroupController, animated: true)
    }

    private func showNewContactController() {
        let newContactController = NewContactController(dcContext: dcContext, searchResult: searchText)
        navigationController?.pushViewController(newContactController, animated: true)
    }

    private func showNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        showChat(chatId: Int(chatId))
    }

    private func showChat(chatId: Int) {
        let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
        navigationController?.pushViewController(chatViewController, animated: true)
        navigationController?.viewControllers.remove(at: 1)
    }

    private func showContactDetail(contactId: Int) {
        let contactDetailController = ContactDetailViewController(dcContext: dcContext, contactId: contactId)
        navigationController?.pushViewController(contactDetailController, animated: true)
    }
}

extension NewChatViewController: ContactListDelegate {
    func deviceContactsImported() {
        contactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF)
        tableView.reloadData()
    }

    func accessGranted() {
        deviceContactAccessGranted = true
    }

    func accessDenied() {
        deviceContactAccessGranted = false
    }

    private func showSettingsAlert() {
        let alert = UIAlertController(
            title: String.localized("import_contacts"),
            message: String.localized("import_contacts_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String.localized("menu_settings"), style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel) { _ in
        })
        present(alert, animated: true)
    }
}

// MARK: - alerts
extension NewChatViewController {
    private func askToDeleteContact(contactId: Int, indexPath: IndexPath) {
        let contact = DcContact(id: contactId)
        let alert = UIAlertController(
            title: String.localizedStringWithFormat(String.localized("ask_delete_contact"), contact.nameNAddr),
            message: nil,
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
            self?.deleteContact(contactId: contactId, indexPath: indexPath)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func askToChatWith(contactId: Int) {
        if dcContext.getChatIdByContactId(contactId: contactId) != 0 {
            self.dismiss(animated: true, completion: nil)
            self.showNewChat(contactId: contactId)
        } else {
            let dcContact = DcContact(id: contactId)
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr),
                                          message: nil,
                                          preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                self.dismiss(animated: true, completion: nil)
                self.showNewChat(contactId: contactId)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
                self.reactivateSearchBarIfNeeded()
            }))
            present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: - UISearchResultsUpdating
extension NewChatViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            filterContentForSearchText(searchText)
        }
    }
}

struct ContactHighlights {
    let contactDetail: ContactDetail
    let indexes: [Int]
}

enum ContactDetail {
    case NAME
    case EMAIL
}

struct ContactWithSearchResults {
    let contact: DcContact
    let indexesToHighlight: [ContactHighlights]
}
