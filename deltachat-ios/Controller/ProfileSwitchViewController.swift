import UIKit
import Intents
import DcCore

class ProfileSwitchViewController: UITableViewController {

    private let dcAccounts: DcAccounts
    private let accountSection = 0
    private let addSection = 1

    private lazy var accountIds: [Int] = {
        return dcAccounts.getAllSorted()
    }()

    private lazy var cancelButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(cancelAction))
    }()

    private lazy var addAccountCell: ActionCell = {
        let cell = ActionCell()
        cell.actionTitle = String.localized("add_account")
        cell.imageView?.image = UIImage(systemName: "plus")
        return cell
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        super.init(style: .insetGrouped)
        setupSubviews()
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnectivityChanged), name: Event.connectivityChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.setRightBarButton(cancelButton, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        tableView.bounces = tableView.contentSize.height > tableView.safeAreaLayoutGuide.layoutFrame.height
    }

    private func setupSubviews() {
        title = String.localized("switch_account")
        tableView.register(AccountCell.self, forCellReuseIdentifier: AccountCell.reuseIdentifier)
        tableView.rowHeight = AccountCell.cellHeight
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
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AccountCell.reuseIdentifier, for: indexPath) as? AccountCell else {
                fatalError("No AccountCell")
            }

            let selectedAccountId = dcAccounts.getSelected().id
            cell.updateCell(selectedAccount: selectedAccountId,
                            dcContext: dcAccounts.get(id: accountIds[indexPath.row]))
            return cell
        }
        return addAccountCell
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return  UIView()
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == accountSection else { return nil }
        let dcContext = dcAccounts.get(id: accountIds[indexPath.row])
        let muteTitle = dcContext.isMuted() ? "menu_unmute" : "menu_mute"
        let muteImage = dcContext.isMuted() ? "speaker.wave.2" : "speaker.slash"

        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }
                let children: [UIMenuElement] = [
                    UIAction.menuAction(localizationKey: muteTitle, systemImageName: muteImage, with: indexPath, action: toggleMute),
                    UIAction.menuAction(localizationKey: "profile_tag", systemImageName: "tag", with: indexPath, action: setProfileTag),
                    UIAction.menuAction(localizationKey: "move_to_top", systemImageName: "arrow.up", with: indexPath, action: moveToTop),
                    UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", with: indexPath, action: deleteAccount),
                ]
                return UIMenu(children: children)
            }
        )
    }

    func toggleMute(at indexPath: IndexPath) {
        let dcContext = dcAccounts.get(id: accountIds[indexPath.row])
        dcContext.setMuted(!dcContext.isMuted())
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    func setProfileTag(at indexPath: IndexPath) {
        let dcContext = dcAccounts.get(id: accountIds[indexPath.row])

        let alert = UIAlertController(title: String.localized("profile_tag"), message: String.localized("profile_tag_explain"), preferredStyle: .alert)
        alert.addTextField { textfield in
            textfield.text = dcContext.getConfig("private_tag")
            textfield.placeholder = String.localized("profile_tag_hint")
        }
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default) { [weak self] _ in
            guard let self, let textfield = alert.textFields?.first else { return }
            dcContext.setConfig("private_tag", textfield.text?.trimmingCharacters(in: .whitespacesAndNewlines))
            tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true)
    }

    func moveToTop(at indexPath: IndexPath) {
        let accountId = accountIds[indexPath.row]
        dcAccounts.moveToTop(id: accountId)
        accountIds = dcAccounts.getAllSorted()
        tableView.reloadData()
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

    func deleteAccount(at indexPath: IndexPath) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        Utils.authenticateDeviceOwner(reason: String.localized("edit_transport")) { [weak self] in
            guard let self else { return }
            let accountId = accountIds[indexPath.row]
            let account = dcAccounts.get(id: accountId)
            let message = "⚠️ " + String.localized(stringID: "delete_account_explain_with_name", parameter: account.displayname ?? account.addr ?? "no addr")
            let alert = UIAlertController(title: String.localized("delete_account_ask"), message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("delete_account"), style: .destructive, handler: { [weak self] _ in
                guard let self else { return }

                appDelegate.locationManager.disableLocationStreamingInAllChats()
                _ = dcAccounts.remove(id: accountId)
                KeychainManager.deleteAccountSecret(id: accountId)
                INInteraction.delete(with: "\(accountId)", completion: nil)
                if dcAccounts.getAll().isEmpty {
                    _ = dcAccounts.add()
                } else {
                    let lastSelectedAccountId = UserDefaults.standard.integer(forKey: Constants.Keys.lastSelectedAccountKey)
                    if lastSelectedAccountId != 0 {
                        _ = dcAccounts.select(id: lastSelectedAccountId)
                    }
                }
                reloadAndExit(appDelegate: appDelegate, previousAccountId: 0)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return assertionFailure()
        }

        tableView.deselectRow(at: indexPath, animated: false)
        let selectedAccountId = dcAccounts.getSelected().id

        switch indexPath.section {
        case accountSection:
            let accountId = accountIds[indexPath.row]
            selectAccount(previousAccountId: selectedAccountId, accountId: accountId, cell: cell)
        case addSection:
            addAccount(previousAccountId: selectedAccountId)
        default:
            assertionFailure("no such tableView section expected")
        }
    }

    @objc private func cancelAction() {
        dismiss(animated: true)
    }

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
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

    private lazy var accountAvatar: InitialsBadge = {
        let avatar = InitialsBadge(size: 37)
        avatar.isAccessibilityElement = false
        return avatar
    }()

    private var selectedAccount: Int?
    private var accountId: Int?

    private lazy var mutedIndicator: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: 16).isActive = true
        view.tintColor = DcColors.middleGray
        view.image = UIImage(systemName: "speaker.slash.fill")?.withRenderingMode(.alwaysTemplate)
        view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = false
        return view
    }()

    private lazy var accountName: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .body, weight: .bold)
        return label
    }()

    private lazy var tagLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .preferredFont(forTextStyle: .subheadline)
        return label
    }()

    lazy var labelStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [accountName, tagLabel])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .leading
        return stackView
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

    private func setupSubviews() {
        contentView.addSubview(accountAvatar)
        contentView.addSubview(mutedIndicator)
        contentView.addSubview(labelStackView)
        let margins = contentView.layoutMarginsGuide
        contentView.addConstraints([
            accountAvatar.constraintCenterYTo(contentView),
            accountAvatar.constraintAlignLeadingToAnchor(margins.leadingAnchor),
            mutedIndicator.constraintCenterYTo(contentView),
            mutedIndicator.constraintToTrailingOf(accountAvatar, paddingLeading: 12),
            labelStackView.constraintAlignTopToAnchor(margins.topAnchor),
            labelStackView.constraintToTrailingOf(mutedIndicator, paddingLeading: 3),
            labelStackView.constraintAlignBottomToAnchor(margins.bottomAnchor),
            labelStackView.constraintAlignTrailingToAnchor(margins.trailingAnchor, paddingTrailing: 32, priority: .defaultHigh),
        ])
    }

    func updateCell(selectedAccount: Int, dcContext: DcContext) {
        let accountId = dcContext.id
        self.accountId = accountId
        self.selectedAccount = selectedAccount
        let encrypted = dcContext.isDatabaseEncrypted() ? "⚠️ " : ""
        let title = dcContext.displayname ?? dcContext.addr ?? ""
        let contact = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF))
        accountAvatar.setColor(contact.color)
        accountAvatar.setName(title)
        if let image = contact.profileImage {
            accountAvatar.setImage(image)
        }

        let unreadMessages = dcContext.getFreshMessagesCount()
        accountAvatar.setUnreadMessageCount(unreadMessages, isMuted: dcContext.isMuted())

        mutedIndicator.isHidden = !dcContext.isMuted()

        accountName.text = encrypted + title
        if unreadMessages > 0 {
            accountName.accessibilityLabel = "\(title): \(String.localized(stringID: "n_messages", parameter: unreadMessages))"
        } else {
            accountName.accessibilityLabel = title
        }

        let connectivityString = DcUtils.getConnectivityString(dcContext: dcContext, connectedString: "")
        if let label = dcContext.getConfig("private_tag") {
            tagLabel.text = if !connectivityString.isEmpty {
                connectivityString + " · " + label
            } else {
                label
            }
            tagLabel.isHidden = false
        } else if !connectivityString.isEmpty {
            tagLabel.text = connectivityString
            tagLabel.isHidden = false
        } else {
            tagLabel.isHidden = true
        }

        accessoryType = selectedAccount == accountId ? .checkmark : .none
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accountAvatar.reset()
        accountName.text = nil
        accountId = -1
    }
}
