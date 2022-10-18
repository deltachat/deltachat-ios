import UIKit
import DcCore

class AccountSwitchViewController: UITableViewController {

    private let dcAccounts: DcAccounts
    private let accountSection = 0
    private let addSection = 1
    private let addAccountTag = -1

    private lazy var accountIds: [Int] = {
        return dcAccounts.getAll()
    }()

    private lazy var editButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(barButtonSystemItem: .edit,
                                  target: self,
                                  action: #selector(editAction))
        return btn
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(barButtonSystemItem: .cancel,
                                  target: self,
                                  action: #selector(cancelAction))
        return btn
    }()

    private lazy var addAccountCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = -1
        cell.actionTitle = String.localized("add_account")
        return cell
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        super.init(style: .grouped)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setLeftBarButton(editButton, animated: false)
    }

    private func setupSubviews() {
        title = String.localized("switch_account")
        tableView.register(AccountCell.self, forCellReuseIdentifier: AccountCell.reuseIdentifier)
        tableView.rowHeight = AccountCell.cellHeight
        tableView.separatorStyle = .none
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return AccountCell.cellHeight
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == accountSection {
            return accountIds.count
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == accountSection {
            guard let cell: AccountCell = tableView.dequeueReusableCell(withIdentifier: AccountCell.reuseIdentifier, for: indexPath) as? AccountCell else {
                safe_fatalError("unsupported cell type")
                return UITableViewCell()
            }

            let selectedAccountId = dcAccounts.getSelected().id
            cell.updateCell(selectedAccount: selectedAccountId, dcContext: dcAccounts.get(id: accountIds[indexPath.row]))
            cell.accessoryType = selectedAccountId == accountIds[indexPath.row] ? .checkmark : .none
            return cell
        }
        return addAccountCell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            safe_fatalError()
            return
        }

        tableView.deselectRow(at: indexPath, animated: false)
        let selectedAccountId = dcAccounts.getSelected().id
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let prefs = UserDefaults.standard

        if indexPath.section == accountSection {
            let accountId = cell.tag
            if selectedAccountId == accountId {
                dismiss(animated: true)
                return
            }
            if let row = accountIds.firstIndex(of: selectedAccountId) {
                let index = IndexPath(row: row, section: accountSection)
                let previouslySelectedCell = tableView.cellForRow(at: index)
                previouslySelectedCell?.accessoryType = .none
            }
            cell.accessoryType = .checkmark
            _ = self.dcAccounts.select(id: accountId)
        } else {
            _ = self.dcAccounts.add()
        }

        appDelegate.reloadDcContext()
        prefs.setValue(selectedAccountId, forKey: Constants.Keys.lastSelectedAccountKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    @objc private func editAction() {
        logger.debug("edit Action")
        navigationItem.setLeftBarButton(cancelButton, animated: false)
        setEditing(true, animated: true)
        tableView.reloadData()
    }

    @objc private func cancelAction() {
        logger.debug("cancel Action")
        navigationItem.setLeftBarButton(editButton, animated: false)
        setEditing(false, animated: true)
        tableView.reloadData()
    }
}

class AccountCell: UITableViewCell {

    static let reuseIdentifier = "accountCell_reuse_identifier"
    static var cellHeight: CGFloat {
        let textHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize + UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 24
        if textHeight > 74.5 {
            return textHeight
        }
        return 74.5
    }

    var isLargeText: Bool {
        return UIFont.preferredFont(forTextStyle: .body).pointSize > 36
    }

    lazy var accountAvatar: InitialsBadge = {
        let avatar = InitialsBadge(size: 52, accessibilityLabel: "")
        return avatar
    }()

    lazy var accountName: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .body, weight: .bold)
        label.textColor = DcColors.defaultTextColor
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupSubviews() {
        contentView.addSubview(accountAvatar)
        contentView.addSubview(accountName)
        let margins = contentView.layoutMarginsGuide
        contentView.addConstraints([
            accountAvatar.constraintCenterYTo(contentView),
            accountAvatar.constraintAlignLeadingToAnchor(margins.leadingAnchor),
            accountName.constraintAlignTopToAnchor(margins.topAnchor),
            accountName.constraintToTrailingOf(accountAvatar, paddingLeading: 10),
            accountName.constraintAlignBottomToAnchor(margins.bottomAnchor),
            accountName.constraintAlignTrailingToAnchor(margins.trailingAnchor, paddingTrailing: 32)
        ])
        backgroundColor = .clear
    }

    public func updateCell(selectedAccount: Int, dcContext: DcContext) {
        let accountId = dcContext.id
        let title = dcContext.displayname ?? dcContext.addr ?? ""
        let contact = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF))
        accountAvatar.setColor(contact.color)
        accountAvatar.setName(title)
        if let image = contact.profileImage {
            accountAvatar.setImage(image)
        }
        accountName.text = title
        if isEditing {
            accessoryType = .none
        } else {
            if selectedAccount == accountId {
                accessoryType = .checkmark
            } else {
                accessoryType = .none
            }
        }
        
        tag = accountId
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accountAvatar.reset()
        accountName.text = nil
        tag = -1
    }
}
