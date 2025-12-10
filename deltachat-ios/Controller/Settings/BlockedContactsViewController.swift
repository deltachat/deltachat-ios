import UIKit
import DcCore

class BlockedContactsViewController: GroupMembersViewController, GroupMemberSelectionDelegate {

    var emptyStateView: EmptyStateLabel = {
        let view =  EmptyStateLabel()
        view.text = String.localized("blocked_empty_hint")
        return view
    }()

    override init(dcContext: DcContext) {
        super.init(dcContext: dcContext)
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
        emptyStateView.addCenteredTo(parentView: view)
    }

    // MARK: - actions + updates
    func selected(contactId: Int, selected: Bool) {
        if !selected {
            let dcContact = dcContext.getContact(id: contactId)
            let title = dcContact.displayName
            let alert = UIAlertController(title: title, message: String.localized("ask_unblock_contact"), preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("menu_unblock_contact"), style: .default, handler: { [weak self] _ in
                guard let self else { return }
                self.dcContext.unblockContact(id: contactId)
                self.contactIds = self.dcContext.getBlockedContacts()
                self.selectedContactIds = Set(self.contactIds)
                self.tableView.reloadData()
                self.updateEmtpyStateView()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { [weak self] _ in
                guard let self else { return }
                self.selectedContactIds = Set(self.contactIds)
                self.tableView.reloadData()
            }))
           present(alert, animated: true, completion: nil)
        }
    }

    private func updateEmtpyStateView() {
        emptyStateView.isHidden = super.numberOfRowsForContactList > 0
    }
}
