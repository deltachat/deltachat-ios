import Contacts
import UIKit
import DcCore
import Intents

internal final class AdvancedViewController: UITableViewController, ProgressAlertHandler {

    private struct SectionConfigs {
        let headerTitle: String?
        let footerTitle: String?
        let cells: [UITableViewCell]
    }

    private enum CellTags: Int {
        case autocryptPreferences
        case sendAutocryptMessage
        case manageKeys
        case videoChat
        case viewLog
        case accountSettings
    }

    private var dcContext: DcContext
    internal let dcAccounts: DcAccounts

    private let externalPathDescr = "File Sharing/Delta Chat"

    // MARK: - ProgressAlertHandler
    weak var progressAlert: UIAlertController?
    var progressObserver: NSObjectProtocol?

    // MARK: - cells
    private lazy var autocryptSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.isOn = dcContext.e2eeEnabled
        switchControl.addTarget(self, action: #selector(handleAutocryptPreferencesToggle(_:)), for: .valueChanged)
        return switchControl
    }()

    private lazy var autocryptPreferencesCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.tag = CellTags.autocryptPreferences.rawValue
        cell.textLabel?.text = String.localized("autocrypt_prefer_e2ee")
        cell.accessoryView = autocryptSwitch
        cell.selectionStyle = .none
        return cell
    }()

    private lazy var sendAutocryptMessageCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.sendAutocryptMessage.rawValue
        cell.actionTitle = String.localized("autocrypt_send_asm_title")
        return cell
    }()

    private lazy var manageKeysCell: ActionCell = {
        let cell = ActionCell()
        cell.tag = CellTags.manageKeys.rawValue
        cell.actionTitle = String.localized("pref_manage_keys")
        return cell
    }()

    private lazy var accountSettingsCell: UITableViewCell = {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_password_and_account_settings")
        cell.accessoryType = .disclosureIndicator
        cell.tag = CellTags.accountSettings.rawValue
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
                        preferredStyle: .safeActionSheet)
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
                    case .authorized:
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
        let experimentalSection = SectionConfigs(
            headerTitle: String.localized("pref_experimental_features"),
            footerTitle: nil,
            cells: [videoChatInstanceCell, broadcastListsCell, locationStreamingCell])
        let appAccessSection = SectionConfigs(
            headerTitle: String.localized("pref_app_access"),
            footerTitle: String.localized("pref_show_system_contacts_explain"),
            cells: [showSystemContactsCell])
        let autocryptSection = SectionConfigs(
            headerTitle: String.localized("pref_encryption"),
            footerTitle: nil,
            cells: [autocryptPreferencesCell, manageKeysCell, sendAutocryptMessageCell]
        )
        let serverSection = SectionConfigs(
            headerTitle: String.localized("pref_server"),
            footerTitle: String.localized("pref_only_fetch_mvbox_explain"),
            cells: [accountSettingsCell, sentboxWatchCell, sendCopyToSelfCell, mvboxMoveCell, onlyFetchMvboxCell])
        return [viewLogSection, experimentalSection, appAccessSection, autocryptSection, serverSection]
    }()

    init(dcAccounts: DcAccounts) {
        self.dcContext = dcAccounts.getSelected()
        self.dcAccounts = dcAccounts
        super.init(style: .grouped)
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addProgressAlertListener(dcAccounts: dcAccounts, progressName: eventImexProgress) { [weak self] in
            guard let self else { return }
            self.progressAlert?.dismiss(animated: true)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let backupProgressObserver = self.progressObserver {
            NotificationCenter.default.removeObserver(backupProgressObserver)
        }
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
        case .autocryptPreferences: break
        case .sendAutocryptMessage: sendAutocryptSetupMessage()
        case .manageKeys: showManageKeysDialog()
        case .videoChat: showVideoChatInstance()
        case .viewLog: showLogViewController()
        case .accountSettings: showAccountSettingsController()
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

    private func showAccountSettingsController() {
        let controller = AccountSetupController(dcAccounts: dcAccounts, editView: true)
        navigationController?.pushViewController(controller, animated: true)
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

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func presentError(message: String) {
        let error = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        error.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel))
        present(error, animated: true)
    }

    private func startImex(what: Int32, passphrase: String? = nil) {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            showProgressAlert(title: String.localized(what==DC_IMEX_IMPORT_SELF_KEYS ? "pref_managekeys_import_secret_keys" : "pref_managekeys_export_secret_keys"), dcContext: dcContext)
            DispatchQueue.main.async {
                self.dcAccounts.stopIo()
                self.dcContext.imex(what: what, directory: documents[0], passphrase: passphrase)
            }
        } else {
            logger.error("document directory not found")
        }
    }

    // MARK: - updates
    private func updateCells() {
        videoChatInstanceCell.detailTextLabel?.text = VideoChatInstanceViewController.getValString(val: dcContext.getConfig("webrtc_instance") ?? "")
    }

    // MARK: - coordinator
    private func showVideoChatInstance() {
        let videoInstanceController = VideoChatInstanceViewController(dcContext: dcContext)
        navigationController?.pushViewController(videoInstanceController, animated: true)
    }
}
