import ALCameraViewController
import Contacts
import UIKit
import DcCore

class NewChatViewController: UITableViewController {
    weak var coordinator: NewChatCoordinator?

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

    var syncObserver: Any?
    var hud: ProgressHud?

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        deviceContactAccessGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let nc = NotificationCenter.default
        syncObserver = nc.addObserver(
            forName: dcNotificationSecureJoinerProgress,
            object: nil,
            queue: nil
        ) { notification in
            if let ui = notification.userInfo {
                if ui["error"] as? Bool ?? false {
                    self.hud?.error(ui["errorMessage"] as? String)
                } else if ui["done"] as? Bool ?? false {
                    self.hud?.done()
                } else {
                    self.hud?.progress(ui["progress"] as? Int ?? 0)
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        let nc = NotificationCenter.default
        if let syncObserver = self.syncObserver {
            nc.removeObserver(syncObserver)
        }
    }

    @objc func cancelButtonPressed() {
        dismiss(animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
           return Constants.defaultCellHeight
        } else if section == sectionImportedContacts {
            if deviceContactAccessGranted {
                return ContactCell.cellHeight
            } else {
                return Constants.defaultCellHeight
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
                coordinator?.showNewGroupController(isVerified: false)
            } else if row == sectionNewRowNewVerifiedGroup {
                coordinator?.showNewGroupController(isVerified: true)
            } else if row == sectionNewRowNewContact {
                coordinator?.showNewContactController()
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
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.section == sectionContacts {
            let contactId = contactIdByRow(indexPath.row)

            let edit = UITableViewRowAction(style: .normal, title: String.localized("info")) { [unowned self] _, _ in
                if self.searchController.isActive {
                    self.searchController.dismiss(animated: false) {
                        self.coordinator?.showContactDetail(contactId: contactId)
                    }
                } else {
                    self.coordinator?.showContactDetail(contactId: contactId)
                }
            }

            let delete = UITableViewRowAction(style: .destructive, title: String.localized("delete")) { [unowned self] _, _ in
                //handle delete
                if let dcContext = self.coordinator?.dcContext {
                    let contactId = self.contactIdByRow(indexPath.row)
                    self.askToDeleteContact(contactId: contactId, context: dcContext)
                }
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

    private func askToDeleteContact(contactId: Int, context: DcContext) {
        let contact = DcContact(id: contactId)
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_delete_contact"), contact.nameNAddr),
                                      message: nil,
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            if context.deleteContact(contactId: contactId) {
                self.contactIds = self.dcContext.getContacts(flags: DC_GCL_ADD_SELF)
                self.tableView.reloadData()
            }
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func askToChatWith(contactId: Int) {
        if dcContext.getChatIdByContactId(contactId: contactId) != 0 {
            self.dismiss(animated: true, completion: nil)
            self.coordinator?.showNewChat(contactId: contactId)
        } else {
            let dcContact = DcContact(id: contactId)
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr),
                                          message: nil,
                                          preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                self.dismiss(animated: true, completion: nil)
                self.coordinator?.showNewChat(contactId: contactId)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
                self.reactivateSearchBarIfNeeded()
            }))
            present(alert, animated: true, completion: nil)
        }
    }

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
