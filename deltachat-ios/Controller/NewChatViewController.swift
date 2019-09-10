import ALCameraViewController
import Contacts
import UIKit

class NewChatViewController: UITableViewController {
    weak var coordinator: NewChatCoordinator?

    private let sectionNew = 0
    private let sectionImportedContacts = 1
    private let sectionNewRowNewGroup = 0
    private let sectionNewRowScanQrCode = 1
    private let sectionNewRowNewContact = 2

    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        return searchController
    }()

    var contactIds: [Int] = Utils.getContactIds() {
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

    // weak var chatDisplayer: ChatDisplayer?

    var syncObserver: Any?
    var hud: ProgressHud?

    lazy var deviceContactHandler: DeviceContactsHandler = {
        let handler = DeviceContactsHandler()
        handler.contactListDelegate = self
        return handler
    }()

    var deviceContactAccessGranted: Bool = false {
        didSet {
            tableView.reloadData()
        }
    }

    init() {
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        deviceContactAccessGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
        contactIds = Utils.getContactIds()
        // this will show the searchbar on launch -> will be set back to true on viewDidAppear
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = true
        }

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
        return deviceContactAccessGranted ? 2 : 3
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == sectionNew {
            return 3
        } else if section == sectionImportedContacts {
            if deviceContactAccessGranted {
                return isFiltering() ? filteredContacts.count : contacts.count
            } else {
                return 1
            }
        } else {
            return isFiltering() ? filteredContacts.count : contacts.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if section == sectionNew {
            if row == sectionNewRowNewGroup {
                // new group row
                let cell: UITableViewCell
                if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
                    cell = c
                } else {
                    cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
                }
                cell.textLabel?.text = String.localized("menu_new_group")
                cell.textLabel?.textColor = view.tintColor

                return cell
            }
            if row == sectionNewRowScanQrCode {
                // scan QR code row
                let cell: UITableViewCell
                if let c = tableView.dequeueReusableCell(withIdentifier: "scanGroupCell") {
                    cell = c
                } else {
                    cell = UITableViewCell(style: .default, reuseIdentifier: "scanGroupCell")
                }
                cell.textLabel?.text = String.localized("qrscan_title")
                cell.textLabel?.textColor = view.tintColor

                return cell
            }

            if row == sectionNewRowNewContact {
                // new contact row
                let cell: UITableViewCell
                if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
                    cell = c
                } else {
                    cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
                }
                cell.textLabel?.text = String.localized("menu_new_contact")
                cell.textLabel?.textColor = view.tintColor

                return cell
            }
        } else if section == sectionImportedContacts {
            // import device contacts section
            if deviceContactAccessGranted {
                let cell: ContactCell
                if let c = tableView.dequeueReusableCell(withIdentifier: "contactCell") as? ContactCell {
                    cell = c
                } else {
                    cell = ContactCell(style: .default, reuseIdentifier: "contactCell")
                }
                let contact: ContactWithSearchResults = contactSearchResultByRow(row)
                updateContactCell(cell: cell, contactWithHighlight: contact)
                return cell
            } else {
                let cell: ActionCell
                if let c = tableView.dequeueReusableCell(withIdentifier: "actionCell") as? ActionCell {
                    cell = c
                } else {
                    cell = ActionCell(style: .default, reuseIdentifier: "actionCell")
                }
                cell.actionTitle = String.localized("import_contacts")
                return cell
            }
        } else {
            // section contact list if device contacts are not imported
            let cell: ContactCell
            if let c = tableView.dequeueReusableCell(withIdentifier: "contactCell") as? ContactCell {
                cell = c
            } else {
                cell = ContactCell(style: .default, reuseIdentifier: "contactCell")
            }

            let contact: ContactWithSearchResults = contactSearchResultByRow(row)
            updateContactCell(cell: cell, contactWithHighlight: contact)
            return cell
        }
        // will actually never get here but compiler not happy
        return UITableViewCell(style: .default, reuseIdentifier: "cell")
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        let section = indexPath.section

        if section == sectionNew {
            if row == sectionNewRowNewGroup {
                coordinator?.showNewGroupController()
            }
            if row == sectionNewRowScanQrCode {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    coordinator?.showQRCodeController()
                } else {
                    let alert = UIAlertController(title: String.localized("chat_camera_unavailable"), message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel, handler: { _ in
                        self.dismiss(animated: true, completion: nil)
                    }))
                    present(alert, animated: true, completion: nil)
                }
            }
            if row == sectionNewRowNewContact {
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
        let contactId = contactIdByRow(indexPath.row)

        let edit = UITableViewRowAction(style: .default, title: String.localized("global_menu_edit_desktop")) { [unowned self] _, _ in
            if self.searchController.isActive {
                self.searchController.dismiss(animated: false) {
                    self.coordinator?.showContactDetail(contactId: contactId)
                }
            } else {
                self.coordinator?.showContactDetail(contactId: contactId)
            }
        }
        edit.backgroundColor = DcColors.primary
        return [edit]
    }

    private func contactIdByRow(_ row: Int) -> Int {
        return isFiltering() ? filteredContacts[row].contact.id : contactIds[row]
    }

    private func contactSearchResultByRow(_ row: Int) -> ContactWithSearchResults {
        return isFiltering() ? filteredContacts[row] : contacts[row]
    }

    private func askToChatWith(contactId: Int) {
        let dcContact = DcContact(id: contactId)
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.nameNAddr),
                                      message: nil,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            self.coordinator?.showNewChat(contactId: contactId)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
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

    private func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    private func filterContentForSearchText(_ searchText: String, scope _: String = String.localized("pref_show_emails_all")) {
        let contactsWithHighlights: [ContactWithSearchResults] = contacts.map { contact in
            let indexes = contact.contact.containsExact(searchText: searchText)
            return ContactWithSearchResults(contact: contact.contact, indexesToHighlight: indexes)
        }

        filteredContacts = contactsWithHighlights.filter { !$0.indexesToHighlight.isEmpty }
        tableView.reloadData()
    }
}

extension NewChatViewController: QrCodeReaderDelegate {
    func handleQrCode(_ code: String) {
        logger.info("decoded: \(code)")

        let check = dc_check_qr(mailboxPointer, code)!
        logger.info("got ver: \(check)")

        if dc_lot_get_state(check) == DC_QR_ASK_VERIFYGROUP {
            hud = ProgressHud(String.localized("synchronizing_account"), in: view)
            DispatchQueue.global(qos: .userInitiated).async {
                let id = dc_join_securejoin(mailboxPointer, code)

                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        self.coordinator?.showChat(chatId: Int(id))
                        // self.chatDisplayer?.displayChatForId(chatId: Int(id))
                    }
                }
            }
        } else {
            let alert = UIAlertController(title: String.localized("invalid_qr_code"), message: code, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("OK"), style: .default, handler: { _ in
                self.dismiss(animated: true, completion: nil)
            }))
            present(alert, animated: true, completion: nil)
        }
        dc_lot_unref(check)
    }
}

extension NewChatViewController: ContactListDelegate {
    func deviceContactsImported() {
        contactIds = Utils.getContactIds()
        //		tableView.reloadData()
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
