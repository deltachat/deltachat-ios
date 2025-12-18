import Contacts
import UIKit
import DcCore
import Intents

internal final class AdvancedViewController: UITableViewController {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case defaultTagValue = 0
        case showEmails
        case viewLog
        case transportSettings
        case proxySettings
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    private let externalPathDescr = "File Sharing/Delta Chat"

    // MARK: - cells
    private lazy var showEmailsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.showEmails.rawValue
        cell.textLabel?.text = String.localized("pref_show_emails")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        return cell
    }()

    private lazy var transportSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("transports")
        cell.accessoryType = .disclosureIndicator
        cell.tag = CellTags.transportSettings.rawValue
        return cell
    }()

    private lazy var proxySettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("proxy_settings")
        cell.accessoryType = .disclosureIndicator
        cell.tag = CellTags.proxySettings.rawValue
        return cell
    }()

    lazy var multiDeviceModeCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_multidevice"),
            on: dcContext.getConfigBool("bcc_self"),
            action: { cell in
                if cell.isOn {
                    self.dcContext.setConfigBool("bcc_self", true)
                } else {
                    let alert = UIAlertController(title: String.localized("pref_multidevice"),
                        message: String.localized("pref_multidevice_change_warn"),
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String.localized("perm_continue"), style: .destructive, handler: { [weak self] _ in
                        self?.dcContext.setConfigBool("bcc_self", false)
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { [weak self] _ in
                        cell.uiSwitch.setOn(true, animated: true)
                    }))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                }
        })
    }()

    lazy var mvboxMoveCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_auto_folder_moves"),
            on: dcContext.getConfigBool("mvbox_move"),
            action: { cell in
                self.dcContext.setConfigBool("mvbox_move", cell.isOn)
        })
    }()

    lazy var onlyFetchMvboxCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_only_fetch_mvbox_title"),
            on: dcContext.getConfigBool("only_fetch_mvbox"),
            action: { cell in
                if cell.isOn {
                    let alert = UIAlertController(title: String.localized("pref_only_fetch_mvbox_title"),
                        message: String.localized("pref_imap_folder_warn_disable_defaults"),
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String.localized("perm_continue"), style: .destructive, handler: { [weak self] _ in
                        self?.dcContext.setConfigBool("only_fetch_mvbox", true)
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { [weak self] _ in
                        cell.uiSwitch.setOn(false, animated: true)
                    }))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                } else {
                    self.dcContext.setConfigBool("only_fetch_mvbox", false)
                }
        })
    }()

    lazy var broadcastListsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("channels"),
            on: UserDefaults.standard.bool(forKey: "broadcast_lists"),
            action: { cell in
                UserDefaults.standard.set(cell.isOn, forKey: "broadcast_lists")
                if cell.isOn {
                    let alert = UIAlertController(title: "Thanks for trying out experimental 🧪 \"Channels\"!",
                        message: "You can now create new \"Channels\" from the \"New Chat\" dialog\n\n"
                               + "If you want to quit the experimental feature, you can disable it at \"Settings / Advanced\".",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                }
        })
    }()

    lazy var callsCell: SwitchCell = {
        return SwitchCell(
            textLabel: "Debug Calls",
            on: UserDefaults.standard.bool(forKey: "pref_calls_enabled"),
            action: { cell in
                UserDefaults.standard.set(cell.isOn, forKey: "pref_calls_enabled")
                if cell.isOn {
                    let alert = UIAlertController(title: "Thanks for helping to debug 🧪 \"Calls\"!",
                        message: "You can now debug calls using the phone-icon in one-to-one-chats\n\n"
                               + "The experiment is about making decentralised calls work and reliable at all, not about options or UI. "
                               + "We're happy about focused feedback at support.delta.chat",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                }
        })
    }()

    lazy var locationStreamingCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_on_demand_location_streaming"),
            on: UserDefaults.standard.bool(forKey: "location_streaming"),
            action: { cell in
                UserDefaults.standard.set(cell.isOn, forKey: "location_streaming")
                if cell.isOn {
                    let alert = UIAlertController(title: "Thanks for trying out the experimental feature 🧪 \"Location streaming\"",
                        message: "You will find a corresponding option in the attach menu (the paper clip) of each chat now.\n\n"
                               + "Moreover, \"Profiles\" and \"All Media\" will offer a map.\n\n"
                               + "If you want to quit the experimental feature, you can disable it at \"Settings / Advanced\".",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                }
        })
    }()

    private lazy var viewLogCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.viewLog.rawValue
        cell.textLabel?.text = String.localized("pref_view_log")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private lazy var sections: [SectionConfigs] = {
        let viewLogSection = SectionConfigs(
            headerTitle: nil,
            footerTitle: nil,
            cells: [viewLogCell])
        let serverSection = SectionConfigs(
            headerTitle: String.localized("pref_server"),
            footerTitle: String.localized("pref_multidevice_explain"),
            cells: [transportSettingsCell, proxySettingsCell, multiDeviceModeCell])
        let experimentalSection = SectionConfigs(
            headerTitle: String.localized("pref_experimental_features"),
            footerTitle: String.localized("pref_experimental_features_explain"),
            cells: [broadcastListsCell, callsCell, locationStreamingCell])

        if dcContext.isChatmail {
            return [viewLogSection, serverSection, experimentalSection]
        } else {
            let legacySection = SectionConfigs(
                headerTitle: "Legacy Options",
                footerTitle: nil,
                cells: [showEmailsCell, mvboxMoveCell, onlyFetchMvboxCell])
            return [viewLogSection, serverSection, experimentalSection, legacySection]
        }
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_advanced")
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateCells()
    }

    // MARK: - UITableViewDelegate + UITableViewDatasource
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
        case .showEmails: showClassicMailController()

        case .viewLog: showLogViewController()

        case .transportSettings:
            Utils.authenticateDeviceOwner(reason: String.localized("edit_transport")) { [weak self] in
                self?.showTransportsViewController()
            }
        case .proxySettings:
            showProxySettings()
        case .defaultTagValue: break
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].headerTitle
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sections[section].footerTitle
    }

    // MARK: - actions
    private func showSystemContactsRestrictedAlert() {
        let alert = UIAlertController(title: String.localized("import_device_contacts"), message: String.localized("import_device_contacts_hint"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("menu_settings"), style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }

    private func showLogViewController() {
        let controller = LogViewController(dcContext: dcContext)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showClassicMailController() {
        let controller = EmailOptionsViewController(dcContext: dcContext)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showTransportsViewController() {
        let controller = TransportListViewController(dcContext: dcContext, dcAccounts: dcAccounts)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showProxySettings() {
        let proxySettingsController = ProxySettingsViewController(dcContext: dcContext, dcAccounts: dcAccounts)
        navigationController?.pushViewController(proxySettingsController, animated: true)
    }

    private func presentError(message: String) {
        let error = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        error.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel))
        present(error, animated: true)
    }

    // MARK: - updates
    private func updateCells() {
        showEmailsCell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        proxySettingsCell.detailTextLabel?.text = dcContext.isProxyEnabled ? String.localized("on") : nil
    }
}
