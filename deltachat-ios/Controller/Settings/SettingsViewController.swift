import UIKit
import DcCore
import Intents

internal final class SettingsViewController: UITableViewController {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]

        init(headerTitle: String? = nil, footerTitle: String? = nil, cells: [UITableViewCell]) {
            self.headerTitle = headerTitle
            self.footerTitle = footerTitle
            self.cells = cells
        }
    }

    private enum CellTags: Int {
        case profile
        case chatsAndMedia
        case addAnotherDevice
        case notifications
        case selectBackground
        case advanced
        case help
        case allAppsAndMedia
        case connectivity
        case inviteFriends
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    // MARK: - cells
    private lazy var profileCell: ContactCell = {
        let cell = ContactCell(style: .default, reuseIdentifier: nil)
        let cellViewModel = ProfileViewModel(context: dcContext)
        cell.updateCell(cellViewModel: cellViewModel)
        cell.tag = CellTags.profile.rawValue
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var chatsAndMediaCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.chatsAndMedia.rawValue
        cell.textLabel?.text = String.localized("pref_chats")
        cell.imageView?.image = UIImage(systemName: "message")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var notificationCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.notifications.rawValue
        cell.textLabel?.text = String.localized("pref_notifications")
        cell.imageView?.image = UIImage(systemName: "bell")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var addAnotherDeviceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.addAnotherDevice.rawValue
        cell.textLabel?.text = String.localized("multidevice_title")
        let imageName = if #available(iOS 15, *) { "ipad.and.iphone" } else { "rectangle.on.rectangle" }
        cell.imageView?.image = UIImage(systemName: imageName)
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var advancedCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.advanced.rawValue
        cell.textLabel?.text = String.localized("menu_advanced")
        let imageName = if #available(iOS 15, *) { "chevron.left.forwardslash.chevron.right" } else { "chevron.left.slash.chevron.right" }
        cell.imageView?.image = UIImage(systemName: imageName)
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var allAppsAndMediaCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.allAppsAndMedia.rawValue
        cell.textLabel?.text =  String.localized("all_apps_and_media")
        cell.imageView?.image = UIImage(systemName: "square.grid.2x2")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var inviteFriendsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.inviteFriends.rawValue
        cell.textLabel?.text = String.localized("invite_friends")
        cell.imageView?.image = UIImage(systemName: "heart")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var helpCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.help.rawValue
        cell.textLabel?.text = String.localized("menu_help")
        cell.imageView?.image = UIImage(systemName: "questionmark.circle")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var connectivityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.tag = CellTags.connectivity.rawValue
        cell.textLabel?.text = String.localized("connectivity")
        cell.imageView?.image = UIImage(systemName: "arrow.up.arrow.down")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var selectBackgroundCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.tag = CellTags.selectBackground.rawValue
        cell.textLabel?.text = String.localized("pref_background")
        cell.imageView?.image = UIImage(systemName: "photo")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        var appNameAndVersion = "Delta Chat"
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appNameAndVersion += " v" + appVersion
        }
        let profileSection = SectionConfigs(
            headerTitle: String.localized("pref_profile_info_headline"),
            cells: [self.profileCell]
        )
        let preferencesSection = SectionConfigs(
            cells: [self.chatsAndMediaCell, self.notificationCell, self.selectBackgroundCell, self.addAnotherDeviceCell, self.connectivityCell, self.advancedCell]
        )
        let listsSection = SectionConfigs(
            cells: [allAppsAndMediaCell]
        )
        let helpSection = SectionConfigs(
            footerTitle: appNameAndVersion,
            cells: [inviteFriendsCell, helpCell]
        )

        return [profileSection, preferencesSection, listsSection, helpSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .insetGrouped)

        // set connectivity changed observer before we acutally init `connectivityCell.detailTextLabel` in `updateCells()`,
        // otherwise, we may miss events and the label is not correct.
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.handleConnectivityChanged(_:)), name: Event.connectivityChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_settings")
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        notificationCell.detailTextLabel?.text = " " // nil does not reserve space for the warning calculated in background
        updateCells()
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            return ContactCell.cellHeight
        } else {
            return UITableView.automaticDimension
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return sections[indexPath.section].cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), let cellTag = CellTags(rawValue: cell.tag) else {
            return assertionFailure()
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .profile: showEditSettingsController()
        case .chatsAndMedia: showChatsAndMedia()
        case .addAnotherDevice: showBackupProviderViewController()
        case .notifications: showNotificationsViewController()
        case .advanced: showAdvanced()
        case .allAppsAndMedia: showAllAppsAndMedia()
        case .help: openHelp()
        case .connectivity: showConnectivity()
        case .selectBackground: selectBackground()
        case .inviteFriends: inviteFriends()
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    // MARK: - Notifications
    @objc private func handleConnectivityChanged(_ notification: Notification) {
        guard dcContext.id == notification.userInfo?["account_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.connectivityCell.detailTextLabel?.text = DcUtils.getConnectivityString(dcContext: self.dcContext,
                                                                                   connectedString: String.localized("connectivity_connected"))
            updateNotificationCell()
        }
    }

    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        if navigationController?.visibleViewController == self {
            updateNotificationCell()
        }
    }

    // MARK: - updates
    private func updateCells() {
        profileCell.updateCell(cellViewModel: ProfileViewModel(context: dcContext))
        connectivityCell.detailTextLabel?.text = DcUtils.getConnectivityString(dcContext: dcContext,
                                                                               connectedString: String.localized("connectivity_connected"))
        updateNotificationCell()
    }

    private func updateNotificationCell() {
        NotificationsViewController.getNotificationStatus(dcContext: dcContext) { warning in
            DispatchQueue.runOnMain { [weak self] in
                guard let self else { return }
                if let warning {
                    notificationCell.detailTextLabel?.text = "⚠️ " + warning
                } else {
                    notificationCell.detailTextLabel?.text = String.localized(dcContext.isMuted() ? "off" : "on")
                }
            }
        }
    }

    // MARK: - coordinator
    private func showEditSettingsController() {
        let editController = SelfProfileViewController(dcAccounts: dcAccounts)
        navigationController?.pushViewController(editController, animated: true)
    }

    private func showChatsAndMedia() {
        navigationController?.pushViewController(ChatsAndMediaViewController(dcAccounts: dcAccounts), animated: true)
    }

    private func showNotificationsViewController() {
        navigationController?.pushViewController(NotificationsViewController(dcAccounts: dcAccounts), animated: true)
    }

    private func showBackupProviderViewController() {
        let alert = UIAlertController(title: String.localized("multidevice_title"), message: String.localized("multidevice_this_creates_a_qr_code"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(
            title: String.localized("perm_continue"),
            style: .default,
            handler: { [weak self] _ in
                Utils.authenticateDeviceOwner(reason: String.localized("multidevice_this_creates_a_qr_code")) { [weak self] in
                    guard let self else { return }
                    self.navigationController?.pushViewController(BackupTransferViewController(dcAccounts: self.dcAccounts), animated: true)
                }
            }
        ))
        present(alert, animated: true)
    }

    private func showAdvanced() {
        navigationController?.pushViewController(AdvancedViewController(dcAccounts: dcAccounts), animated: true)
    }

    private func showAllAppsAndMedia() {
        navigationController?.pushViewController(AllMediaViewController(dcContext: dcContext), animated: true)
    }

    private func showConnectivity() {
        navigationController?.pushViewController(ConnectivityViewController(dcContext: dcContext), animated: true)
    }

    private func selectBackground() {
        navigationController?.pushViewController(WallpaperViewController(dcContext: dcContext), animated: true)
    }

    private func inviteFriends() {
        guard let inviteLink = Utils.getInviteLink(context: dcContext, chatId: 0) else { return }

        let invitationText = String.localized(stringID: "invite_friends_text", parameter: inviteLink)
        Utils.share(text: invitationText, parentViewController: self, sourceView: inviteFriendsCell)
    }
}
