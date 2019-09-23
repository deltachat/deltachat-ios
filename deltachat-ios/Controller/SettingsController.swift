import JGProgressHUD
import QuickTableViewController
import UIKit

internal final class SettingsViewController: QuickTableViewController {
    weak var coordinator: SettingsCoordinator?

    private var dcContext: DcContext

    let documentInteractionController = UIDocumentInteractionController()
    var backupProgressObserver: Any?
    var configureProgressObserver: Any?

    private lazy var hudHandler: HudHandler = {
        let hudHandler = HudHandler(parentView: self.view)
        return hudHandler
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_settings")
        let backButton = UIBarButtonItem(title: String.localized("menu_settings"), style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        documentInteractionController.delegate = self as? UIDocumentInteractionControllerDelegate
    }

    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)
        let nc = NotificationCenter.default
        backupProgressObserver = nc.addObserver(
            forName: dcNotificationImexProgress,
            object: nil,
            queue: nil
        ) { notification in
            if let ui = notification.userInfo {
                if ui["error"] as? Bool ?? false {
                    self.hudHandler.setHudError(ui["errorMessage"] as? String)
                } else if ui["done"] as? Bool ?? false {
                    self.hudHandler.setHudDone(callback: nil)
                } else {
                    self.hudHandler.setHudProgress(ui["progress"] as? Int ?? 0)
                }
            }
        }
        configureProgressObserver = nc.addObserver(
            forName: dcNotificationConfigureProgress,
            object: nil,
            queue: nil
        ) { notification in
            if let ui = notification.userInfo {
                if ui["error"] as? Bool ?? false {
                    self.hudHandler.setHudError(ui["errorMessage"] as? String)
                } else if ui["done"] as? Bool ?? false {
                    self.hudHandler.setHudDone(callback: nil)
                } else {
                    self.hudHandler.setHudProgress(ui["progress"] as? Int ?? 0)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setTable()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        let nc = NotificationCenter.default
        if let backupProgressObserver = self.backupProgressObserver {
            nc.removeObserver(backupProgressObserver)
        }
        if let configureProgressObserver = self.configureProgressObserver {
            nc.removeObserver(configureProgressObserver)
        }
    }

    private func setTable() {
        let subtitle = String.localized("pref_default_status_label") + ": "
            + (DcConfig.selfstatus ?? "-")

        tableContents = [
            Section(
                title: String.localized("pref_profile_info_headline"),
                rows: [
                    NavigationRow(text: DcConfig.displayname ?? String.localized("pref_your_name"),
                        detailText: .subtitle(subtitle),
                        action: { _ in
                            self.coordinator?.showEditSettingsController()
                    }),
                    NavigationRow(text: String.localized("pref_password_and_account_settings"),
                        detailText: .none,
                        action: { _ in
                            self.coordinator?.showAccountSetupController()
                    }),
                ]
            ),

            Section(
                title: String.localized("pref_communication"),
                rows: [
                    NavigationRow(text: String.localized("pref_show_emails"),
                                  detailText: .value1(SettingsClassicViewController.getValString(val: DcConfig.showEmails)),
                              action: { [weak self] in self?.showClassicMail($0) }),
                    NavigationRow(text: String.localized("pref_blocked_contacts"),
                              detailText: .none,
                              action: { [weak self] in self?.showBlockedContacts($0) }),
                    SwitchRow(text: String.localized("pref_read_receipts"),
                              switchValue: DcConfig.mdnsEnabled,
                              action: { row in
                                if let row = row as? SwitchRow {
                                    DcConfig.mdnsEnabled = row.switchValue
                                }
                    }),
                ],
                footer: String.localized("pref_read_receipts_explain")
            ),

            Section(
                title: String.localized("pref_imap_folder_handling"),
                rows: [
                    SwitchRow(text: String.localized("pref_watch_inbox_folder"),
                              switchValue: DcConfig.inboxWatch,
                              action: { row in
                                if let row = row as? SwitchRow {
                                    DcConfig.inboxWatch = row.switchValue
                                }
                    }),
                    SwitchRow(text: String.localized("pref_watch_sent_folder"),
                              switchValue: DcConfig.sentboxWatch,
                              action: { row in
                                if let row = row as? SwitchRow {
                                    DcConfig.sentboxWatch = row.switchValue
                                }
                    }),
                    SwitchRow(text: String.localized("pref_watch_mvbox_folder"),
                              switchValue: DcConfig.mvboxWatch,
                              action: { row in
                                if let row = row as? SwitchRow {
                                    DcConfig.mvboxWatch = row.switchValue
                                }
                    }),
                    SwitchRow(text: String.localized("pref_auto_folder_moves"),
                              switchValue: DcConfig.mvboxMove,
                              action: { row in
                                if let row = row as? SwitchRow {
                                    DcConfig.mvboxMove = row.switchValue
                                }
                    }),
                ],
                footer: String.localized("pref_auto_folder_moves_explain")
            ),

            Section(
                title: String.localized("autocrypt"),
                rows: [
                    SwitchRow(text: String.localized("autocrypt_prefer_e2ee"),
                              switchValue: DcConfig.e2eeEnabled,
                              action: { row in
                                if let row = row as? SwitchRow {
                                    DcConfig.e2eeEnabled = row.switchValue
                                }
                    }),
                    TapActionRow(text: String.localized("autocrypt_send_asm_title"), action: { [weak self] in self?.sendAsm($0) }),
                ],
                footer: String.localized("autocrypt_explain")
            ),

            Section(
                title: String.localized("pref_backup"),
                rows: [
                    TapActionRow(text: String.localized("export_backup_desktop"), action: { [weak self] in self?.createBackup($0) }),
                ],
                footer: String.localized("pref_backup_explain")
            ),
        ]
    }

    private func createBackup(_: Row) {
        let alert = UIAlertController(title: String.localized("pref_backup_export_explain"), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: String.localized("pref_backup_export_start_button"), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            if !documents.isEmpty {
                logger.info("create backup in \(documents)")
                self.hudHandler.showHud(String.localized("one_moment"))
                DispatchQueue.main.async {
                    dc_imex(mailboxPointer, DC_IMEX_EXPORT_BACKUP, documents[0], nil)
                }
            } else {
                logger.error("document directory not found")
            }
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func showClassicMail(_: Row) {
        coordinator?.showClassicMail()
    }

    private func showBlockedContacts(_: Row) {
        coordinator?.showBlockedContacts()
    }

    private func sendAsm(_: Row) {
        let askAlert = UIAlertController(title: String.localized("autocrypt_send_asm_explain_before"), message: nil, preferredStyle: .actionSheet)
        askAlert.addAction(UIAlertAction(title: String.localized("autocrypt_send_asm_title"), style: .default, handler: { _ in
            let waitAlert = UIAlertController(title: String.localized("one_moment"), message: nil, preferredStyle: .alert)
            waitAlert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default, handler: { _ in self.dcContext.stopOngoingProcess() }))
            self.present(waitAlert, animated: true, completion: nil)
            DispatchQueue.global(qos: .background).async {
                let sc = self.dcContext.initiateKeyTransfer()
                DispatchQueue.main.async {
                    waitAlert.dismiss(animated: true, completion: nil)
                    guard var sc = sc else {
                        return
                    }
                    if sc.count == 44 {
                        // format setup code to the typical 3 x 3 numbers
                        sc = sc.substring(0, 4) + "  -  " + sc.substring(5, 9) + "  -  " + sc.substring(10, 14) + "  -\n\n" +
                            sc.substring(15, 19) + "  -  " + sc.substring(20, 24) + "  -  " + sc.substring(25, 29) + "  -\n\n" +
                            sc.substring(30, 34) + "  -  " + sc.substring(35, 39) + "  -  " + sc.substring(40, 44)
                    }

                    let text = String.localizedStringWithFormat(String.localized("autocrypt_send_asm_explain_after"), sc)
                    let showAlert = UIAlertController(title: text, message: nil, preferredStyle: .alert)
                    showAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
                    self.present(showAlert, animated: true, completion: nil)
                }
            }
        }))
        askAlert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(askAlert, animated: true, completion: nil)
    }

    private func configure(_: Row) {
        hudHandler.showHud(String.localized("configuring_account"))
        dc_configure(mailboxPointer)
    }
}
