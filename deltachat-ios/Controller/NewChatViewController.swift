import Contacts
import UIKit
import DcCore

class NewChatViewController: UITableViewController {
    private let dcContext: DcContext

    enum NewOption {
        case scanQRCode
        case newGroup
        case newBroadcastList
        case newEmail
    }

    private let newOptions: [NewOption]

    private let sectionNew = 0
    private let sectionContacts = 1
    private let sectionInviteFriends = 2
    
    private let sectionsCount = 3

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
        label.backgroundColor = nil
        label.textColor = DcColors.defaultTextColor
        label.paddingBottom = 64
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

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        self.contactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF)

        var newOptions: [NewOption]
        if UserDefaults.standard.bool(forKey: "broadcast_lists") {
            newOptions = [.scanQRCode, .newGroup, .newBroadcastList]
        } else {
            newOptions = [.scanQRCode, .newGroup]
        }
        if self.dcContext.isChatmail == false {
            newOptions.append(.newEmail)
        }
        self.newOptions = newOptions

        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = String.localized("menu_new_chat")

        navigationItem.searchController = searchController
        definesPresentationContext = true // to make sure searchbar will only be shown in this viewController
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        tableView.sectionHeaderHeight = UITableView.automaticDimension
    }

    // MARK: - actions

    private func inviteFriends(cell: UITableViewCell) {
        guard let inviteLink = Utils.getInviteLink(context: dcContext, chatId: 0) else { return }

        let invitationText = String.localized(stringID: "invite_friends_text", parameter: inviteLink)
        Utils.share(text: invitationText, parentViewController: self, sourceView: cell)
    }

    @objc func cancelButtonPressed() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Table view data source
    override func numberOfSections(in _: UITableView) -> Int {
        return sectionsCount
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == sectionNew {
            return newOptions.count
        } else if section == sectionInviteFriends {
            return 1
        } else {
            return isFiltering ? filteredContactIds.count : contactIds.count
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = indexPath.section
        if section == sectionNew || section == sectionInviteFriends {
            return UITableView.automaticDimension
        } else {
            return ContactCell.cellHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row
        
        if section == sectionNew {
            guard let actionCell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseIdentifier, for: indexPath) as? ActionCell else { fatalError("No Action Cell") }

            switch newOptions[row] {
            case .scanQRCode:
                actionCell.imageView?.image = UIImage(systemName: "qrcode")
                actionCell.actionTitle = String.localized("menu_new_contact")
            case .newGroup:
                actionCell.imageView?.image = UIImage(systemName: "plus")
                actionCell.actionTitle = String.localized("menu_new_group")
            case .newBroadcastList:
                actionCell.imageView?.image = UIImage(systemName: "plus")
                actionCell.actionTitle = String.localized("new_channel")
            case .newEmail:
                actionCell.imageView?.image = UIImage(systemName: "plus")
                actionCell.actionTitle = String.localized("new_email")
            }

            return actionCell
        } else if section == sectionInviteFriends {
            guard let actionCell = tableView.dequeueReusableCell(withIdentifier: ActionCell.reuseIdentifier, for: indexPath) as? ActionCell else { fatalError("No Action Cell") }

            actionCell.imageView?.image = UIImage(systemName: "heart")
            actionCell.actionTitle = String.localized("invite_friends")
            return actionCell

        } else {
            guard let contactCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell else { fatalError("ContactCell expected") }

            let contactCellViewModel = self.contactViewModelBy(row: indexPath.row)
            contactCell.updateCell(cellViewModel: contactCellViewModel)
            return contactCell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == sectionContacts {
            return String.localized("chat_with")
        }
        return nil
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        let section = indexPath.section

        if section == sectionNew {
            let newOption = newOptions[row]
            if newOption == .scanQRCode {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.appCoordinator.presentQrCodeController()
                }
            } else if newOption == .newGroup {
                showNewGroupController(createMode: .createGroup)
            } else if newOption == .newBroadcastList {
                showNewGroupController(createMode: .createBroadcast)
            } else if newOption == .newEmail {
                showNewGroupController(createMode: .createEmail)
            }
        } else if section == sectionInviteFriends, let cell = tableView.cellForRow(at: indexPath) {
            inviteFriends(cell: cell)
        } else {
            showChatAt(row: row)
        }
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.section == sectionContacts {
            let contactId = contactIdByRow(indexPath.row)

            let profileAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completionHandler in
                guard let self else { return }
                if self.searchController.isActive {
                    self.searchController.dismiss(animated: false) {
                        self.showContactDetail(contactId: contactId)
                    }
                } else {
                    self.showContactDetail(contactId: contactId)
                }
                completionHandler(true)
            }
            profileAction.accessibilityLabel = String.localized("profile")
            profileAction.backgroundColor = UIColor.systemBlue
            profileAction.image = Utils.makeImageWithText(image: UIImage(systemName: "person.crop.circle"), text: String.localized("profile"))

            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completionHandler in
                guard let self else { return }
                self.askToDeleteContact(contactId: contactIdByRow(indexPath.row), indexPath: indexPath) {
                    completionHandler(true)
                }
            }
            deleteAction.accessibilityLabel = String.localized("delete")
            deleteAction.image = Utils.makeImageWithText(image: UIImage(systemName: "trash"), text: String.localized("delete"))

            return UISwipeActionsConfiguration(actions: [profileAction, deleteAction])
        } else {
            return nil
        }
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
    private func showNewGroupController(createMode: NewGroupController.CreateMode) {
        let newGroupController = NewGroupController(dcContext: dcContext, createMode: createMode)
        navigationController?.pushViewController(newGroupController, animated: true)
    }

    private func showNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        showChat(chatId: Int(chatId))
    }

    private func showChat(chatId: Int) {
        if let chatlistViewController = navigationController?.viewControllers[0] as? ChatListViewController {
            let chatViewController = ChatViewController(dcContext: dcContext, chatId: chatId)
            chatlistViewController.backButtonUpdateableDataSource = chatViewController
            navigationController?.setViewControllers([chatlistViewController, chatViewController], animated: true)
        }
    }

    private func showContactDetail(contactId: Int) {
        navigationController?.pushViewController(ProfileViewController(dcContext, contactId: contactId), animated: true)
    }
}

// MARK: - alerts
extension NewChatViewController {
    private func askToDeleteContact(contactId: Int, indexPath: IndexPath, didDelete: (() -> Void)? = nil) {
        let contact = dcContext.getContact(id: contactId)
        let alert = UIAlertController(
            title: String.localizedStringWithFormat(String.localized("ask_delete_contact"), contact.displayName),
            message: nil,
            preferredStyle: .safeActionSheet
        )
        alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { [weak self] _ in
            self?.deleteContact(contactId: contactId, indexPath: indexPath)
            didDelete?()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func askToChatWith(contactId: Int) {
        if dcContext.getChatIdByContactId(contactId) != 0 {
            self.dismiss(animated: true, completion: nil)
            self.showNewChat(contactId: contactId)
        } else {
            let dcContact = dcContext.getContact(id: contactId)
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), dcContact.displayName),
                                          message: nil,
                                          preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { [weak self] _ in
                self?.showNewChat(contactId: contactId)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { [weak self] _ in
                self?.reactivateSearchBarIfNeeded()
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
