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

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
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
            TapActionRow(text: "Create backup", action: { [weak self] in self?.createBackup($0) }),
        ]

        let deleteRow = TapActionRow(text: "Delete Account", action: { [weak self] in self?.deleteAccount($0) })

        tableContents = [
            Section(
                title: "User Details",
                rows: [
                    NavigationRow(text: "Display Name", detailText: .value1(DCConfig.displayname ?? ""), action: { [weak self] in self?.editNameAndStatus($0)}),
                    NavigationRow(text: "Status", detailText: .value1(DCConfig.selfstatus ?? ""), action: { [weak self] in self?.editNameAndStatus($0)}),
                    TapActionRow(text: "Configure my Account", action: { [weak self] in self?.presentAccountSetup($0) }),
                ]
            ),
            Section(
                title: "Flags",
                rows: [
                    SwitchRow(text: "E2EE enabled", switchValue: DCConfig.e2eeEnabled, action: editCell()),
                    SwitchRow(text: "Read Receipts", switchValue: DCConfig.mdnsEnabled, action: editCell()),
                    SwitchRow(text: "Watch Inbox", switchValue: DCConfig.inboxWatch, action: editCell()),
                    SwitchRow(text: "Watch Sentbox", switchValue: DCConfig.sentboxWatch, action: editCell()),
                    SwitchRow(text: "Watch Mvbox", switchValue: DCConfig.mvboxWatch, action: editCell()),
                    SwitchRow(text: "Move to Mvbox", switchValue: DCConfig.mvboxMove, action: editCell()),
                    SwitchRow(text: "Save Mime Headers", switchValue: DCConfig.saveMimeHeaders, action: editCell()),
                ]
            ),

            Section(
                title: "Backup",
                rows: backupRows
            ),

            Section(title: "Danger", rows: [
                deleteRow,
            ]),
        ]
    }

    // FIXME: simplify this method
    // swiftlint:disable cyclomatic_complexity
    private func editCell() -> (Row) -> Void {
        return { [weak self] sender in
            logger.info("row edit", sender.text)

            let title = sender.text
            let subtitle: String = sender.detailText?.text ?? ""


            if let sender = sender as? SwitchRow {
                logger.info("got bool switch")
                let value = sender.switchValue

                switch title {
                case "E2EE enabled":
                    DCConfig.e2eeEnabled = value
                case "Read Receipts":
                    DCConfig.mdnsEnabled = value
                case "Watch Inbox":
                    DCConfig.inboxWatch = value
                case "Watch Sentbox":
                    DCConfig.sentboxWatch = value
                case "Watch Mvbox":
                    DCConfig.mvboxWatch = value
                case "Move to Mvbox":
                    DCConfig.mvboxMove = value
                case "Save Mime Headers":
                    DCConfig.saveMimeHeaders = value
                default:
                    logger.info("unknown title", title)
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
            hudHandler.showBackupHud("Creating Backup")
            DispatchQueue.main.async {
                dc_imex(mailboxPointer, DC_IMEX_EXPORT_BACKUP, documents[0], nil)
            }
        } else {
            logger.error("document directory not found")
        }
    }

    private func configure(_: Row) {
        hudHandler.showBackupHud("Configuring account")
        dc_configure(mailboxPointer)
    }

    private func deleteAccount(_: Row) {
        logger.info("deleting account")
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        let dbfile = appDelegate.dbfile()
        let dburl = URL(fileURLWithPath: dbfile, isDirectory: false)
        let alert = UIAlertController(title: "Delete Account", message: "Are you sure you wante to delete your account data?", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
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
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func presentAccountSetup(_: Row) {
        coordinator?.showAccountSetupController()
    }

    private func editNameAndStatus(_ row: Row) {
        guard let option = SettingsEditOption(rawValue: row.text) else { return }
        coordinator?.showEditSettingsController(option: option)
    }
}

enum SettingsEditOption: String {
    case DISPLAYNAME = "Display Name"
    case STATUS = "Status"
}
