import UIKit
import DcCore

protocol GroupMemberSelectionDelegate: AnyObject {
    func selected(contactId: Int, selected: Bool)
}

// MARK: - GroupMembersViewController
class GroupMembersViewController: UITableViewController {
    weak var groupMemberSelectionDelegate: GroupMemberSelectionDelegate?
    var enableCheckmarks = true
    var numberOfSections = 1
    let dcContext: DcContext

    // MARK: - datasource
    var contactIds: [Int] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    // used when seachbar is active
    private var filteredContactIds: [Int] = []

    var numberOfRowsForContactList: Int {
        return isFiltering ? filteredContactIds.count : contactIds.count
    }

    var selectedContactIds: Set<Int> = []

    private func contactIdByRow(_ row: Int) -> Int {
        return isFiltering ? filteredContactIds[row] : contactIds[row]
    }

    private func contactViewModelBy(row: Int) -> ContactCellViewModel {
        let id = contactIdByRow(row)
        return ContactCellViewModel.make(contactId: id, searchText: searchText, dcContext: dcContext)
    }

    // MARK: - search
    // searchBar active?
    private var isFiltering: Bool {
        return searchController.isActive && !searchBarIsEmpty
    }

    private var searchBarIsEmpty: Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    open var searchText: String? {
        return searchController.searchBar.text
    }
    
    open func filterContactIds(queryString: String) -> [Int] {
        return dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: searchText)
    }

    // MARK: - subview configuration
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

    private lazy var emptySearchStateLabelWidthConstraint: NSLayoutConstraint? = {
        return emptySearchStateLabel.widthAnchor.constraint(equalTo: tableView.widthAnchor)
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        configureTableView()
        definesPresentationContext = true
    }

    // MARK: - setup + configuration

    private func configureTableView() {
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)
        tableView.sectionHeaderHeight = UITableView.automaticDimension
    }

    // MARK: - UITableView datasource + delegate
    override func numberOfSections(in _: UITableView) -> Int {
        return numberOfSections
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return numberOfRowsForContactList
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ContactCell.cellHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return updateContactCell(for: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectContactCell(at: indexPath)
    }

    func updateContactCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let cell: ContactCell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell else {
            assertionFailure("unsupported cell type")
            return UITableViewCell()
        }

        let row = indexPath.row
        let cellViewModel = contactViewModelBy(row: indexPath.row)
        cell.updateCell(cellViewModel: cellViewModel)
        cell.accessoryType = selectedContactIds.contains(contactIdByRow(row)) && enableCheckmarks ? .checkmark : .none
        return cell
    }

    // MARK: - actions
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
}

// MARK: - UISearchResultsUpdating
extension GroupMembersViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text {
            filterContentForSearchText(searchText)
        }
    }

    private func filterContentForSearchText(_ searchText: String, scope _: String = String.localized("pref_show_emails_all")) {
        filteredContactIds = filterContactIds(queryString: searchText)
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
}
