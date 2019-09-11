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

    static let e2eeEnabled: Int = 1
    static let readReceipts: Int = 2
    static let watchInbox: Int = 3
    static let watchSentbox: Int = 4
    static let watchMvBox: Int = 5
    static let MvToMvbox: Int = 6
    private typealias SVC = SettingsViewController

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
        NavBarUtils.setBigTitle(navigationController: navigationController)
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
                        action: { [weak self] in
                            self?.editNameAndStatus($0)
                    }),
                    NavigationRow(text: String.localized("pref_password_and_account_settings"),
                        detailText: .none,
                        action: { [weak self] in
                            self?.presentAccountSetup($0)
                    }),
                ]
            ),

            Section(
                title: String.localized("pref_communication"),
                rows: [
                    SwitchRow(text: String.localized("pref_read_receipts"),
                              switchValue: DcConfig.mdnsEnabled,
                              action: editCell(key: SVC.readReceipts)),
                ],
                footer: String.localized("pref_read_receipts_explain")
            ),

            Section(
                title: String.localized("pref_imap_folder_handling"),
                rows: [
                    SwitchRow(text: String.localized("pref_watch_inbox_folder"),
                              switchValue: DcConfig.inboxWatch,
                              action: editCell(key: SVC.watchInbox)),
                    SwitchRow(text: String.localized("pref_watch_sent_folder"),
                              switchValue: DcConfig.sentboxWatch,
                              action: editCell(key: SVC.watchSentbox)),
                    SwitchRow(text: String.localized("pref_watch_mvbox_folder"),
                              switchValue: DcConfig.mvboxWatch,
                              action: editCell(key: SVC.watchMvBox)),
                    SwitchRow(text: String.localized("pref_auto_folder_moves"),
                              switchValue: DcConfig.mvboxMove,
                              action: editCell(key: SVC.MvToMvbox)),
                ],
                footer: String.localized("pref_auto_folder_moves_explain")
            ),

            Section(
                title: String.localized("autocrypt"),
                rows: [
                    SwitchRow(text: String.localized("autocrypt_prefer_e2ee"),
                              switchValue: DcConfig.e2eeEnabled,
                              action: editCell(key: SVC.e2eeEnabled)),
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

            Section(
                title: String.localized("danger"),
                rows: [
                    TapActionRow(text: String.localized("delete_account"), action: { [weak self] in self?.deleteAccount($0) }),
                ]
            ),
        ]
    }

    // FIXME: simplify this method
    private func editCell(key: Int) -> (Row) -> Void {
        return { sender in
            logger.info("row edit", sender.text)

            if let sender = sender as? SwitchRow {
                logger.info("got bool switch")
                let value = sender.switchValue
                switch key {
                case SVC.e2eeEnabled:
                    DcConfig.e2eeEnabled = value
                case SVC.readReceipts:
                    DcConfig.mdnsEnabled = value
                case SVC.watchInbox:
                    DcConfig.inboxWatch = value
                case SVC.watchSentbox:
                    DcConfig.sentboxWatch = value
                case SVC.watchMvBox:
                    DcConfig.mvboxWatch = value
                case SVC.MvToMvbox:
                    DcConfig.mvboxMove = value
                default:
                    logger.info("unknown key", String(key))
                }
                return
            }
        }
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

    private func sendAsm(_: Row) {
        let alert = UIAlertController(title: String.localized("autocrypt_send_asm_explain_before"), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: String.localized("autocrypt_send_asm_title"), style: .default, handler: { _ in
            //dcContext.intiateKeyTransfer()
            self.dismiss(animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func configure(_: Row) {
        hudHandler.showHud(String.localized("configuring_account"))
        dc_configure(mailboxPointer)
    }

    private func deleteAccount(_: Row) {
        logger.info("deleting account")
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        let dbfile = appDelegate.dbfile()
        let dburl = URL(fileURLWithPath: dbfile, isDirectory: false)
        let alert = UIAlertController(title: String.localized("delete_account_message"),
                                      message: nil,
                                      preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: String.localized("delete_account"), style: .destructive, handler: { _ in
            appDelegate.stop()
            appDelegate.close()
            do {
                try FileManager.default.removeItem(at: dburl)
            } catch {
                logger.error("failed to delete db: \(error)")
            }

            appDelegate.open()
            appDelegate.start()

            // refresh our view
            self.setTable()
            self.tableView.reloadData()
            self.dismiss(animated: false, completion: nil)
            self.coordinator?.showLoginController()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func presentAccountSetup(_: Row) {
        coordinator?.showAccountSetupController()
    }

    private func editNameAndStatus(_ row: Row) {
        coordinator?.showEditSettingsController()
    }
}
