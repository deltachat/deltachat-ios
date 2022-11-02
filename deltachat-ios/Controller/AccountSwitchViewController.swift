import UIKit
import Intents
import DcCore

class AccountSwitchViewController: UITableViewController {

    private let dcAccounts: DcAccounts
    private let accountSection = 0
    private let addSection = 1
    private var showAccountDeletion: Bool = false

    private lazy var accountIds: [Int] = {
        return dcAccounts.getAll()
    }()

    private lazy var editButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(barButtonSystemItem: .edit,
                                  target: self,
                                  action: #selector(editAction))
        return btn
    }()

    private lazy var cancelEditButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(barButtonSystemItem: .cancel,
                                  target: self,
                                  action: #selector(cancelEditAction))
        return btn
    }()

    private lazy var doneButton: UIBarButtonItem = {
        let btn = UIBarButtonItem(barButtonSystemItem: .done,
                                  target: self,
                                  action: #selector(doneAction))
        return btn
    }()

    private lazy var addAccountCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("add_account")
        cell.backgroundColor = .clear
        return cell
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        showAccountDeletion = false
        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setLeftBarButton(editButton, animated: false)
        navigationItem.setRightBarButton(doneButton, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        tableView.bounces = tableView.contentSize.height > tableView.safeAreaLayoutGuide.layoutFrame.height
    }

    private func setupSubviews() {
        title = String.localized("switch_account")
        tableView.register(AccountCell.self, forCellReuseIdentifier: AccountCell.reuseIdentifier)
        tableView.rowHeight = AccountCell.cellHeight
        tableView.separatorStyle = .singleLine
        tableView.delegate = self
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
            cell.updateCell(selectedAccount: selectedAccountId,
                            showAccountDeletion: showAccountDeletion,
                            dcContext: dcAccounts.get(id: accountIds[indexPath.row]))
            return cell
        }
        return addAccountCell
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == addSection {
            let guide = self.view.safeAreaLayoutGuide
            let controllerHeight = guide.layoutFrame.size.height
            let contentHeight = CGFloat(accountIds.count + 1) * AccountCell.cellHeight + (view.safeAreaInsets.vertical / 2)
            let diff = controllerHeight - contentHeight
            if diff > 12 {
                return diff
            }
            return 12
        }
        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return  UIView()
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return  UIView()
    }

    func selectAccount(previousAccountId: Int, accountId: Int, cell: UITableViewCell) {
        if previousAccountId == accountId {
            dismiss(animated: true)
            return
        }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        _ = self.dcAccounts.select(id: accountId)
        tableView.reloadData()
        reloadAndExit(appDelegate: appDelegate, previousAccountId: previousAccountId)
    }

    func addAccount(previousAccountId: Int) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        _ = self.dcAccounts.add()
        reloadAndExit(appDelegate: appDelegate, previousAccountId: previousAccountId)
    }

    func reloadAndExit(appDelegate: AppDelegate, previousAccountId: Int) {
        appDelegate.reloadDcContext()
        UserDefaults.standard.setValue(previousAccountId, forKey: Constants.Keys.lastSelectedAccountKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    func deleteAccount(accountId: Int) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        let prefs = UserDefaults.standard
        let confirm1 = UIAlertController(title: String.localized("delete_account_ask"), message: nil, preferredStyle: .safeActionSheet)
        confirm1.addAction(UIAlertAction(title: String.localized("delete_account"), style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            let account = self.dcAccounts.get(id: accountId)
            let confirm2 = UIAlertController(title: account.displaynameAndAddr,
                message: String.localized("forget_login_confirmation_desktop"), preferredStyle: .alert)
            confirm2.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { [weak self] _ in
                guard let self = self else { return }
                appDelegate.locationManager.disableLocationStreamingInAllChats()
                self.dcAccounts.stopIo()
                _ = self.dcAccounts.remove(id: accountId)
                self.dcAccounts.startIo()
                KeychainManager.deleteAccountSecret(id: accountId)
                INInteraction.delete(with: "\(accountId)", completion: nil)
                if self.dcAccounts.getAll().isEmpty {
                    _ = self.dcAccounts.add()
                } else {
                    let lastSelectedAccountId = prefs.integer(forKey: Constants.Keys.lastSelectedAccountKey)
                    if lastSelectedAccountId != 0 {
                        _ = self.dcAccounts.select(id: lastSelectedAccountId)
                    }
                }
                self.reloadAndExit(appDelegate: appDelegate, previousAccountId: 0)
            }))
            confirm2.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            self.present(confirm2, animated: true, completion: nil)
        }))
        confirm1.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        self.present(confirm1, animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            safe_fatalError()
            return
        }

        tableView.deselectRow(at: indexPath, animated: false)
        let selectedAccountId = dcAccounts.getSelected().id

        switch indexPath.section {
        case accountSection:
            let accountId = accountIds[indexPath.row]
            if showAccountDeletion {
                deleteAccount(accountId: accountId)
            } else {
                selectAccount(previousAccountId: selectedAccountId, accountId: accountId, cell: cell)
            }
        case addSection:
            addAccount(previousAccountId: selectedAccountId)
        default:
            safe_fatalError("no such tableView section expected")
        }
    }

    @objc private func editAction() {
        logger.debug("edit Action")
        title = String.localized("delete_account")
        navigationItem.setLeftBarButton(nil, animated: true)
        navigationItem.setRightBarButton(cancelEditButton, animated: true)
        showAccountDeletion = true
        tableView.reloadData()
    }

    @objc private func cancelEditAction() {
        logger.debug("cancel Action")
        title = String.localized("switch_account")
        navigationItem.setLeftBarButton(editButton, animated: false)
        navigationItem.setRightBarButton(doneButton, animated: false)
        showAccountDeletion = false
        tableView.reloadData()
    }

    @objc private func doneAction() {
        logger.debug("done Action")
        dismiss(animated: true)
    }
}

class AccountCell: UITableViewCell {

    static let reuseIdentifier = "accountCell_reuse_identifier"
    static var cellHeight: CGFloat {
        let textHeight = UIFont.preferredFont(forTextStyle: .body).pointSize + 24
        if textHeight > 54 {
            return textHeight
        }
        return 54
    }

    var isLargeText: Bool {
        return UIFont.preferredFont(forTextStyle: .body).pointSize > 36
    }

    lazy var accountAvatar: InitialsBadge = {
        let avatar = InitialsBadge(size: 37)
        avatar.isAccessibilityElement = false
        return avatar
    }()

    var selectedAccount: Int?
    var accountId: Int?

    public lazy var stateIndicator: UIImageView = {
        let view: UIImageView = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var accountName: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .body, weight: .bold)
        label.textColor = DcColors.defaultTextColor
        return label
    }()

    private lazy var backgroundContainer: BackgroundContainer = {
        let container = BackgroundContainer()
        container.image = UIImage(color: DcColors.accountSwitchBackgroundColor)
        container.contentMode = .scaleToFill
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
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
        contentView.addSubview(stateIndicator)
        let margins = contentView.layoutMarginsGuide
        contentView.addConstraints([
            accountAvatar.constraintCenterYTo(contentView),
            accountAvatar.constraintAlignLeadingToAnchor(margins.leadingAnchor),
            accountName.constraintAlignTopToAnchor(margins.topAnchor),
            accountName.constraintToTrailingOf(accountAvatar, paddingLeading: 20),
            accountName.constraintAlignBottomToAnchor(margins.bottomAnchor),
            accountName.constraintAlignTrailingToAnchor(margins.trailingAnchor, paddingTrailing: 32, priority: .defaultLow),
            stateIndicator.constraintCenterYTo(contentView),
            stateIndicator.constraintToTrailingOf(accountName),
            stateIndicator.constraintAlignTrailingToAnchor(margins.trailingAnchor, paddingTrailing: 0),
            stateIndicator.constraintHeightTo(24),
            stateIndicator.constraintWidthTo(24)
        ])
        stateIndicator.isHidden = true
    }

    public func updateCell(selectedAccount: Int, showAccountDeletion: Bool, dcContext: DcContext) {
        let accountId = dcContext.id
        self.accountId = accountId
        self.selectedAccount = selectedAccount
        let title = dcContext.displayname ?? dcContext.addr ?? ""
        let contact = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF))
        accountAvatar.setColor(contact.color)
        accountAvatar.setName(title)
        if let image = contact.profileImage {
            accountAvatar.setImage(image)
        }

        let unreadMessages = dcContext.getFreshMessages().count
        accountAvatar.setUnreadMessageCount(unreadMessages)

        accountName.text = title
        if unreadMessages > 0 {
            accountName.accessibilityLabel = "\(title): \(String.localized(stringID: "n_messages", count: unreadMessages))"
        } else {
            accountName.accessibilityLabel = title
        }

        if showAccountDeletion {
            showDeleteIndicator()
        } else {
            if selectedAccount == accountId {
                showSelectedIndicator()
            } else {
                stateIndicator.image = nil
                stateIndicator.isHidden = true
            }
        }
    }

    private func showDeleteIndicator() {
        let image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "trash")
        } else {
            image = UIImage(named: "ic_trash")
        }
        stateIndicator.image = image
        stateIndicator.tintColor = .systemRed
        stateIndicator.accessibilityLabel = String.localized("delete")
        stateIndicator.isHidden = false

    }

    private func showSelectedIndicator() {
        let image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "checkmark")
        } else {
            image = UIImage(named: "ic_checkmark")
        }
        stateIndicator.image = image
        stateIndicator.tintColor = .systemBlue
        stateIndicator.accessibilityLabel = ""
        stateIndicator.isHidden = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accountAvatar.reset()
        accountName.text = nil
        accountId = -1
        stateIndicator.image = nil
    }
}
