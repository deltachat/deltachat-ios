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
        case sendAutocryptMessage
        case manageKeys
        case videoChat
        case viewLog
        case accountSettings
        case proxySettings
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    private let externalPathDescr = "File Sharing/Delta Chat"

    var progressAlertHandler: ProgressAlertHandler?

    // MARK: - cells
    private lazy var showEmailsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.showEmails.rawValue
        cell.textLabel?.text = String.localized("pref_show_emails")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        return cell
    }()

    private lazy var autocryptSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = dcContext.e2eeEnabled
        switchControl.addTarget(self, action: #selector(handleAutocryptPreferencesToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var autocryptPreferencesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("autocrypt_prefer_e2ee")
        cell.accessoryView = autocryptSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var sendAutocryptMessageCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.sendAutocryptMessage.rawValue
        cell.textLabel?.text = String.localized("autocrypt_send_asm_title")
        return cell
    }()

    private lazy var manageKeysCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.manageKeys.rawValue
        cell.textLabel?.text = String.localized("pref_manage_keys")
        return cell
    }()

    private lazy var accountSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_password_and_account_settings")
        cell.accessoryType = .disclosureIndicator
        cell.tag = CellTags.accountSettings.rawValue
        return cell
    }()

    private lazy var proxySettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("proxy_settings")
        cell.accessoryType = .disclosureIndicator
        cell.tag = CellTags.proxySettings.rawValue
        return cell
    }()

    lazy var sentboxWatchCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_watch_sent_folder"),
            on: dcContext.getConfigBool("sentbox_watch"),
            action: { cell in
                self.dcContext.setConfigBool("sentbox_watch", cell.isOn)
        })
    }()

    lazy var sendCopyToSelfCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_send_copy_to_self"),
            on: dcContext.getConfigBool("bcc_self"),
            action: { cell in
                self.dcContext.setConfigBool("bcc_self", cell.isOn)
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
                    alert.addAction(UIAlertAction(title: String.localized("perm_continue"), style: .destructive, handler: { _ in
                        self.dcContext.setConfigBool("only_fetch_mvbox", true)
                    }))
                    alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
                        cell.uiSwitch.setOn(false, animated: true)
                    }))
                    self.navigationController?.present(alert, animated: true, completion: nil)
                } else {
                    self.dcContext.setConfigBool("only_fetch_mvbox", false)
                }
        })
    }()

    lazy var showSystemContactsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_show_system_contacts"),
            on: dcContext.getConfigBool("ui.ios.show_system_contacts") && CNContactStore.authorizationStatus(for: .contacts) == .authorized,
            action: { cell in
                if cell.isOn {
                    switch CNContactStore.authorizationStatus(for: .contacts) {
                    case .authorized, .limited:
                        self.dcContext.setConfigBool("ui.ios.show_system_contacts", true)
                    case .restricted, .notDetermined:
                        CNContactStore().requestAccess(for: .contacts) { [weak self] granted, _ in
                            DispatchQueue.main.async {
                                if granted {
                                    self?.dcContext.setConfigBool("ui.ios.show_system_contacts", true)
                                } else {
                                    cell.uiSwitch.setOn(false, animated: true)
                                }
                            }
                        }
                    case .denied:
                        self.showSystemContactsRestrictedAlert()
                        cell.uiSwitch.setOn(false, animated: true)
                    @unknown default:
                        cell.uiSwitch.setOn(false, animated: true)
                    }
                } else {
                    self.dcContext.setConfigBool("ui.ios.show_system_contacts", false)
                }
        })
    }()

    private lazy var videoChatInstanceCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.tag = CellTags.videoChat.rawValue
        cell.textLabel?.text = String.localized("videochat_instance")
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    lazy var broadcastListsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("broadcast_lists"),
            on: UserDefaults.standard.bool(forKey: "broadcast_lists"),
            action: { cell in
                UserDefaults.standard.set(cell.isOn, forKey: "broadcast_lists")
                if cell.isOn {
                    let alert = UIAlertController(title: "Thanks for trying out the experimental feature 🧪 \"Broadcast Lists\"!",
                        message: "You can now create new \"Broadcast Lists\" from the \"New Chat\" dialog\n\n"
                               + "In case you are using more than one device, broadcast lists are currently not synced between them\n\n"
                               + "If you want to quit the experimental feature, you can disable it at \"Settings / Advanced\".",
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

    lazy var realtimeChannelsCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("enable_realtime"),
            on: dcContext.getConfigBool("webxdc_realtime_enabled"),
            action: { [weak self] cell in
                self?.dcContext.setConfigBool("webxdc_realtime_enabled", cell.isOn)
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
            footerTitle: String.localized("enable_realtime_explain"),
            cells: [viewLogCell, showEmailsCell, realtimeChannelsCell])
        let experimentalSection = SectionConfigs(
            headerTitle: String.localized("pref_experimental_features"),
            footerTitle: nil,
            cells: [videoChatInstanceCell, broadcastListsCell, locationStreamingCell])

        if dcContext.isChatmail {
            let serverSection = SectionConfigs(
                headerTitle: String.localized("pref_server"),
                footerTitle: nil,
                cells: [accountSettingsCell, proxySettingsCell])
            return [viewLogSection, experimentalSection, serverSection]
        } else {
            let appAccessSection = SectionConfigs(
                headerTitle: String.localized("pref_app_access"),
                footerTitle: String.localized("pref_show_system_contacts_explain"),
                cells: [showSystemContactsCell])
            let encryptionSection = SectionConfigs(
                headerTitle: String.localized("pref_encryption"),
                footerTitle: nil,
                cells: [autocryptPreferencesCell, manageKeysCell, sendAutocryptMessageCell])
            let serverSection = SectionConfigs(
                headerTitle: String.localized("pref_server"),
                footerTitle: String.localized("pref_only_fetch_mvbox_explain"),
                cells: [accountSettingsCell, proxySettingsCell, sentboxWatchCell, sendCopyToSelfCell, mvboxMoveCell, onlyFetchMvboxCell])
            return [viewLogSection, experimentalSection, serverSection, appAccessSection, encryptionSection]
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
            safe_fatalError()
            return
        }
        tableView.deselectRow(at: indexPath, animated: false)

        switch cellTag {
        case .showEmails: showClassicMailController()
        case .sendAutocryptMessage: sendAutocryptSetupMessage()

        case .manageKeys:
            Utils.authenticateDeviceOwner(reason: String.localized("pref_manage_keys")) { [weak self] in
                self?.showManageKeysDialog()
            }

        case .videoChat: showVideoChatInstance()
        case .viewLog: showLogViewController()

        case .accountSettings:
            Utils.authenticateDeviceOwner(reason: String.localized("pref_password_and_account_settings")) { [weak self] in
                self?.showAccountSettingsController()
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
    @objc private func handleAutocryptPreferencesToggle(_ sender: UISwitch) {
        dcContext.e2eeEnabled = sender.isOn
    }

    private func sendAutocryptSetupMessage() {
        let askAlert = UIAlertController(title: String.localized("autocrypt_send_asm_explain_before"), message: nil, preferredStyle: .safeActionSheet)
        askAlert.addAction(UIAlertAction(title: String.localized("autocrypt_send_asm_title"), style: .default, handler: { _ in
                let sc = self.dcContext.initiateKeyTransfer()
                guard var sc = sc else {
                    return
                }
                if sc.count == 44 {
                    // format setup code to the typical 3 x 3 numbers
                    sc = sc.substring(0, 4) + "  -  " + sc.substring(5, 9) + "  -  " + sc.substring(10, 14) + "  -\n\n" +
                        sc.substring(15, 19) + "  -  " + sc.substring(20, 24) + "  -  " + sc.substring(25, 29) + "  -\n\n" +
                        sc.substring(30, 34) + "  -  " + sc.substring(35, 39) + "  -  " + sc.substring(40, 44)
                }

                let text = String.localized("autocrypt_send_asm_explain_after") + "\n\n" + sc
                let showAlert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
                showAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                self.present(showAlert, animated: true, completion: nil)
        }))
        askAlert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(askAlert, animated: true, completion: nil)
    }

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

    private func showAccountSettingsController() {
        let controller = AccountSetupController(dcAccounts: dcAccounts, editView: true)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showProxySettings() {
        let proxySettingsController = ProxySettingsViewController(dcContext: dcContext, dcAccounts: dcAccounts)
        navigationController?.pushViewController(proxySettingsController, animated: true)
    }

    private func showManageKeysDialog() {
        let alert = UIAlertController(title: String.localized("pref_manage_keys"), message: nil, preferredStyle: .safeActionSheet)

        alert.addAction(UIAlertAction(title: String.localized("pref_managekeys_export_secret_keys"), style: .default, handler: { _ in
            let msg = String.localizedStringWithFormat(String.localized("pref_managekeys_export_explain"), self.externalPathDescr)
            let alert = UIAlertController(title: String.localized("pref_managekeys_export_secret_keys"), message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                self.startImex(what: DC_IMEX_EXPORT_SELF_KEYS)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: String.localized("pref_managekeys_import_secret_keys"), style: .default, handler: { _ in
            let msg = String.localizedStringWithFormat(String.localized("pref_managekeys_import_explain"), self.externalPathDescr)
            let alert = UIAlertController(title: String.localized("pref_managekeys_import_secret_keys"), message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { _ in
                self.startImex(what: DC_IMEX_IMPORT_SELF_KEYS)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))

        alert.addAction(UIAlertAction(title: String.localized("learn_more"), style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.navigationController?.pushViewController(HelpViewController(dcContext: self.dcContext, fragment: "#importkey"), animated: true)
        }))

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func presentError(message: String) {
        let error = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        error.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel))
        present(error, animated: true)
    }

    private func startImex(what: Int32, passphrase: String? = nil) {

        let progressHandler = ProgressAlertHandler(dcAccounts: self.dcAccounts, notification: Event.importExportProgress)
        progressHandler.dataSource = self

        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            let alertTitle = String.localized(what==DC_IMEX_IMPORT_SELF_KEYS ? "pref_managekeys_import_secret_keys" : "pref_managekeys_export_secret_keys")
            progressHandler.showProgressAlert(title: alertTitle, dcContext: dcContext)
            DispatchQueue.main.async {
                self.dcAccounts.stopIo()
                self.dcContext.imex(what: what, directory: documents[0], passphrase: passphrase)
            }
        } else {
            logger.error("document directory not found")
        }

        self.progressAlertHandler = progressHandler
    }

    // MARK: - updates
    private func updateCells() {
        showEmailsCell.detailTextLabel?.text = EmailOptionsViewController.getValString(val: dcContext.showEmails)
        videoChatInstanceCell.detailTextLabel?.text = VideoChatInstanceViewController.getValString(val: dcContext.getConfig("webrtc_instance") ?? "")
        proxySettingsCell.detailTextLabel?.text = dcContext.isProxyEnabled ? String.localized("on") : nil
    }

    // MARK: - coordinator
    private func showVideoChatInstance() {
        let videoInstanceController = VideoChatInstanceViewController(dcContext: dcContext)
        navigationController?.pushViewController(videoInstanceController, animated: true)
    }
}
