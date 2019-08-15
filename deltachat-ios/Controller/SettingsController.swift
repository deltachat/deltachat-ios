import JGProgressHUD
import QuickTableViewController
import UIKit

internal final class SettingsViewController: QuickTableViewController {
    weak var coordinator: SettingsCoordinator?

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
    static let SaveMimeHeaders: Int = 7
    private typealias SVC = SettingsViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("menu_settings")
        documentInteractionController.delegate = self as? UIDocumentInteractionControllerDelegate
    }

    override func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)
        let nc = NotificationCenter.default
        backupProgressObserver = nc.addObserver(
            forName: dcNotificationBackupProgress,
            object: nil,
            queue: nil
        ) { notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.hudHandler.setHudError(ui["errorMessage"] as? String)
                } else if ui["done"] as! Bool {
                    self.hudHandler.setHudDone(callback: nil)
                } else {
                    self.hudHandler.setHudProgress(ui["progress"] as! Int)
                }
            }
        }
        configureProgressObserver = nc.addObserver(
            forName: dcNotificationConfigureProgress,
            object: nil,
            queue: nil
        ) { notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.hudHandler.setHudError(ui["errorMessage"] as? String)
                } else if ui["done"] as! Bool {
                    self.hudHandler.setHudDone(callback: nil)
                } else {
                    self.hudHandler.setHudProgress(ui["progress"] as! Int)
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setTable()
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
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
        var backupRows = [
            TapActionRow(text: String.localized("create_backup"), action: { [weak self] in self?.createBackup($0) }),
        ]

        let deleteRow = TapActionRow(text: String.localized("delete_account"), action: { [weak self] in self?.deleteAccount($0) })

        tableContents = [
            Section(
                title: String.localized("user_details"),
                rows: [
                    //FIXME: fix action callback!
                    NavigationRow(text: String.localized("display_name"), detailText: .value1(DCConfig.displayname ?? ""), action: {
                        [weak self] in self?.editNameAndStatus($0, option: SettingsEditOption.DISPLAYNAME)
                    }),
                    NavigationRow(text: String.localized("status"), detailText: .value1(DCConfig.selfstatus ?? ""), action: {
                        [weak self] in self?.editNameAndStatus($0, option: SettingsEditOption.STATUS)
                    }),
                    TapActionRow(text: String.localized("configure_my_account"), action: { [weak self] in self?.presentAccountSetup($0) }),
                ]
            ),
            Section(
                title: String.localized("flags"),
                rows: [
                    SwitchRow(text: String.localized("autocrypt_prefer_e2ee"), switchValue: DCConfig.e2eeEnabled, action: editCell(key: SVC.e2eeEnabled)),
                    SwitchRow(text: String.localized("pref_read_receipts"), switchValue: DCConfig.mdnsEnabled, action: editCell(key: SVC.readReceipts)),
                    SwitchRow(text: String.localized("pref_watch_inbox_folder"), switchValue: DCConfig.inboxWatch, action: editCell(key: SVC.watchMvBox)),
                    SwitchRow(text: String.localized("pref_watch_sent_folder"), switchValue: DCConfig.sentboxWatch, action: editCell(key: SVC.watchSentbox)),
                    SwitchRow(text: String.localized("pref_watch_mvbox_folder"), switchValue: DCConfig.mvboxWatch, action: editCell(key: SVC.watchMvBox)),
                    SwitchRow(text: String.localized("pref_auto_folder_moves"), switchValue: DCConfig.mvboxMove, action: editCell(key: SVC.MvToMvbox)),
                    SwitchRow(text: String.localized("save_mime_headers"), switchValue: DCConfig.saveMimeHeaders, action: editCell(key: SVC.SaveMimeHeaders))
                ]
            ),

            Section(
                title: String.localized("pref_backup"),
                rows: backupRows
            ),

            Section(title: String.localized("danger"), rows: [
                deleteRow,
            ]),
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
                    DCConfig.e2eeEnabled = value
                case SVC.readReceipts:
                    DCConfig.mdnsEnabled = value
                case SVC.watchInbox:
                    DCConfig.inboxWatch = value
                case SVC.watchSentbox:
                    DCConfig.sentboxWatch = value
                case SVC.watchMvBox:
                    DCConfig.mvboxWatch = value
                case SVC.MvToMvbox:
                    DCConfig.mvboxMove = value
                case SVC.SaveMimeHeaders:
                    DCConfig.saveMimeHeaders = value
                default:
                    logger.info("unknown key", String(key))
                }
                return
            }
        }
    }

    private func createBackup(_: Row) {
        // if let documents = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.delta.chat.ios")?.path {

        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            logger.info("create backup in \(documents)")
            hudHandler.showHud(String.localized("creating_backup"))
            DispatchQueue.main.async {
                dc_imex(mailboxPointer, DC_IMEX_EXPORT_BACKUP, documents[0], nil)
            }
        } else {
            logger.error("document directory not found")
        }
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
        let alert = UIAlertController(title: String.localized("delete_account"), message: String.localized("delete_account_message"), preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: String.localized("delete"), style: .destructive, handler: { _ in
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

    private func editNameAndStatus(_ row: Row, option: SettingsEditOption) {
        coordinator?.showEditSettingsController(option: option)
    }
}

enum SettingsEditOption: String {
    case DISPLAYNAME = "Display Name"
    case STATUS = "Status"
}
