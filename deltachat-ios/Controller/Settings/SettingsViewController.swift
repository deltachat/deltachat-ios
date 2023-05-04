import UIKit
import DcCore
import Intents

internal final class SettingsViewController: UITableViewController {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case profile
        case chatsAndMedia
        case addAnotherDevice
        case notifications
        case selectBackground
        case advanced
        case help
        case connectivity
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    private var connectivityChangedObserver: NSObjectProtocol?

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
        cell.textLabel?.text = String.localized("pref_chats_and_media")
        if #available(iOS 16.0, *) {
            cell.imageView?.image = UIImage(systemName: "message") // added in ios13
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var notificationSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = !UserDefaults.standard.bool(forKey: "notifications_disabled")
        switchControl.addTarget(self, action: #selector(handleNotificationToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var notificationCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.notifications.rawValue
        cell.textLabel?.text = String.localized("pref_notifications")
        if #available(iOS 16.0, *) {
            cell.imageView?.image = UIImage(systemName: "bell") // added in ios13
        }
        cell.accessoryView = notificationSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var addAnotherDeviceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.addAnotherDevice.rawValue
        cell.textLabel?.text = String.localized("multidevice_title")
        if #available(iOS 16.0, *) {
            cell.imageView?.image = UIImage(systemName: "macbook.and.iphone") // added in ios16
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var advancedCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.advanced.rawValue
        cell.textLabel?.text = String.localized("menu_advanced")
        if #available(iOS 16.0, *) {
            cell.imageView?.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right") // added in ios15
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var helpCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.help.rawValue
        cell.textLabel?.text = String.localized("menu_help")
        if #available(iOS 16.0, *) {
            cell.imageView?.image = UIImage(systemName: "questionmark.circle") // added in ios13
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var connectivityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.connectivity.rawValue
        cell.textLabel?.text = String.localized("connectivity")
        if #available(iOS 16.0, *) {
            cell.imageView?.image = UIImage(systemName: "arrow.up.arrow.down") // added in ios13
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var selectBackgroundCell: UITableViewCell = {
        let cell = UITableViewCell()
        cell.tag = CellTags.selectBackground.rawValue
        cell.textLabel?.text = String.localized("pref_background")
        if #available(iOS 16.0, *) {
            cell.imageView?.image = UIImage(systemName: "photo") // added in ios13
        }
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
            footerTitle: nil,
            cells: [profileCell]
        )
        let preferencesSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [chatsAndMediaCell, notificationCell, selectBackgroundCell, addAnotherDeviceCell, connectivityCell, advancedCell]
        )
        let helpSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: appNameAndVersion,
            cells: [helpCell]
        )

        return [profileSection, preferencesSection, helpSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .grouped)
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

        // set connectivity changed observer before we acutally init `connectivityCell.detailTextLabel` in `updateCells()`,
        // otherwise, we may miss events and the label is not correct.
        connectivityChangedObserver = NotificationCenter.default.addObserver(forName: dcNotificationConnectivityChanged,
                                                                             object: nil,
                                                                             queue: nil) { [weak self] _ in
            guard let self = self else { return }
            self.connectivityCell.detailTextLabel?.text = DcUtils.getConnectivityString(dcContext: self.dcContext,
                                                                                        connectedString: String.localized("connectivity_connected"))
        }

        updateCells()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let connectivityChangedObserver = self.connectivityChangedObserver {
            NotificationCenter.default.removeObserver(connectivityChangedObserver)
        }
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
            safe_fatalError()
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .profile: showEditSettingsController()
        case .chatsAndMedia: showChatsAndMedia()
        case .addAnotherDevice: showBackupProviderViewController()
        case .notifications: break
        case .advanced: showAdvanced()
        case .help: showHelp()
        case .connectivity: showConnectivity()
        case .selectBackground: selectBackground()
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    // MARK: - actions
    @objc private func handleNotificationToggle(_ sender: UISwitch) {
        UserDefaults.standard.set(!sender.isOn, forKey: "notifications_disabled")
        if sender.isOn {
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.registerForNotifications()
            }
        } else {
            NotificationManager.removeAllNotifications()
        }
        UserDefaults.standard.synchronize()
        NotificationManager.updateApplicationIconBadge(dcContext: dcContext, reset: !sender.isOn)
    }

    // MARK: - updates
    private func updateCells() {
        profileCell.updateCell(cellViewModel: ProfileViewModel(context: dcContext))
        connectivityCell.detailTextLabel?.text = DcUtils.getConnectivityString(dcContext: dcContext,
                                                                               connectedString: String.localized("connectivity_connected"))
    }

    // MARK: - coordinator
    private func showEditSettingsController() {
        let editController = SelfProfileViewController(dcAccounts: dcAccounts)
        navigationController?.pushViewController(editController, animated: true)
    }

    private func showChatsAndMedia() {
        navigationController?.pushViewController(ChatsAndMediaViewController(dcAccounts: dcAccounts), animated: true)
    }

    private func showBackupProviderViewController() {
        let alert = UIAlertController(title: String.localized("multidevice_title"), message: String.localized("multidevice_this_creates_a_qr_code"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(
            title: String.localized("perm_continue"),
            style: .default,
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.navigationController?.pushViewController(BackupTransferViewController(dcAccounts: self.dcAccounts), animated: true)
            }
        ))
        present(alert, animated: true)
    }

    private func showAdvanced() {
        navigationController?.pushViewController(AdvancedViewController(dcAccounts: dcAccounts), animated: true)
    }

    private func showHelp() {
        navigationController?.pushViewController(HelpViewController(dcContext: dcContext), animated: true)
    }

    private func showConnectivity() {
        navigationController?.pushViewController(ConnectivityViewController(dcContext: dcContext), animated: true)
    }

    private func selectBackground() {
        navigationController?.pushViewController(BackgroundOptionsViewController(dcContext: dcContext), animated: true)
    }
}
