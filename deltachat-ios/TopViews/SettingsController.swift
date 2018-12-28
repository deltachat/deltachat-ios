//
//  SettingsController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import JGProgressHUD
import MessageInputBar
import MessageKit
import QuickTableViewController
import UIKit

internal final class SettingsViewController: QuickTableViewController {
    let documentInteractionController = UIDocumentInteractionController()
    var backupProgressObserver: Any?
    var configureProgressObserver: Any?
    var backupHud: JGProgressHUD?

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"

        documentInteractionController.delegate = self as? UIDocumentInteractionControllerDelegate

        setTable()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let nc = NotificationCenter.default
        backupProgressObserver = nc.addObserver(
            forName: dc_notificationBackupProgress,
            object: nil,
            queue: nil
        ) {
            notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.setHudError(ui["errorMessage"] as? String)
                } else if ui["done"] as! Bool {
                    self.setHudDone()
                } else {
                    self.setHudProgress(ui["progress"] as! Int)
                }
            }
        }
        configureProgressObserver = nc.addObserver(
            forName: dc_notificationConfigureProgress,
            object: nil,
            queue: nil
        ) {
            notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.setHudError(ui["errorMessage"] as? String)
                } else if ui["done"] as! Bool {
                    self.setHudDone()
                } else {
                    self.setHudProgress(ui["progress"] as! Int)
                }
            }
        }
    }

    private func setHudError(_ message: String?) {
        if let hud = self.backupHud {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                UIView.animate(
                    withDuration: 0.1, animations: {
                        hud.textLabel.text = message ?? "Error"
                        hud.detailTextLabel.text = nil
                        hud.indicatorView = JGProgressHUDErrorIndicatorView()
                    }
                )

                hud.dismiss(afterDelay: 1.0)
            }
        }
    }

    private func setHudDone() {
        if let hud = self.backupHud {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                UIView.animate(
                    withDuration: 0.1, animations: {
                        hud.textLabel.text = "Success"
                        hud.detailTextLabel.text = nil
                        hud.indicatorView = JGProgressHUDSuccessIndicatorView()
                    }
                )

                hud.dismiss(afterDelay: 1.0)
            }
        }
    }

    private func setHudProgress(_ progress: Int) {
        if let hud = self.backupHud {
            hud.progress = Float(progress) / 1000.0
            hud.detailTextLabel.text = "\(progress / 10)% Complete"
        }
    }

    private func showBackupHud(_ text: String) {
        let hud = JGProgressHUD(style: .dark)
        hud.vibrancyEnabled = true
        hud.indicatorView = JGProgressHUDPieIndicatorView()

        hud.detailTextLabel.text = "0% Complete"
        hud.textLabel.text = text
        hud.show(in: view)

        backupHud = hud
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
        let basicsRows: [Row & RowStyle] = [
            NavigationRow(title: "Email", subtitle: .rightAligned(MRConfig.addr ?? ""), action: editCell()),
            NavigationRow(title: "Password", subtitle: .rightAligned("********"), action: editCell()),
            TapActionRow(title: "Configure", action: { [weak self] in self?.configure($0) }),
        ]
        var backupRows = [
            TapActionRow(title: "Create backup", action: { [weak self] in self?.createBackup($0) }),
            TapActionRow(title: "Restore from backup", action: { [weak self] in self?.restoreBackup($0) }),
        ]

        if MRConfig.configured {
            backupRows.removeLast()
        }

        tableContents = [
            Section(
                title: "Basics",
                rows: basicsRows
            ),

            Section(
                title: "User Details",
                rows: [
                    NavigationRow(title: "Display Name", subtitle: .rightAligned(MRConfig.displayname ?? ""), action: editCell()),
                    NavigationRow(title: "Status", subtitle: .rightAligned(MRConfig.selfstatus ?? ""), action: editCell()),
                ]
            ),

            Section(
                title: "Advanced",
                rows: [
                    NavigationRow(title: "IMAP Server", subtitle: .rightAligned(MRConfig.mailServer ?? MRConfig.configuredMailServer), action: editCell()),
                    NavigationRow(title: "IMAP User", subtitle: .rightAligned(MRConfig.mailUser ?? MRConfig.configuredMailUser), action: editCell()),
                    NavigationRow(title: "IMAP Port", subtitle: .rightAligned(MRConfig.mailPort ?? MRConfig.configuredMailPort), action: editCell()),

                    NavigationRow(title: "SMTP Server", subtitle: .rightAligned(MRConfig.sendServer ?? MRConfig.configuredSendServer), action: editCell()),
                    NavigationRow(title: "SMTP User", subtitle: .rightAligned(MRConfig.sendUser ?? MRConfig.configuredSendUser), action: editCell()),
                    NavigationRow(title: "SMTP Port", subtitle: .rightAligned(MRConfig.sendPort ?? MRConfig.configuredSendPort), action: editCell()),
                    NavigationRow(title: "SMTP Password", subtitle: .rightAligned("********"), action: editCell()),
                ]
            ),

            Section(
                title: "Flags",
                rows: [
                    SwitchRow(title: "E2EE enabled", switchValue: MRConfig.e2eeEnabled, action: editCell()),
                    SwitchRow(title: "MDNS enabled", switchValue: MRConfig.mdnsEnabled, action: editCell()),
                    SwitchRow(title: "Watch Inbox", switchValue: MRConfig.inboxWatch, action: editCell()),
                    SwitchRow(title: "Watch Sentbox", switchValue: MRConfig.sentboxWatch, action: editCell()),
                    SwitchRow(title: "Watch Mvbox", switchValue: MRConfig.mvboxWatch, action: editCell()),
                    SwitchRow(title: "Move to Mvbox", switchValue: MRConfig.mvboxMove, action: editCell()),
                    SwitchRow(title: "Save Mime Headers", switchValue: MRConfig.saveMimeHeaders, action: editCell()),
                ]
            ),

            Section(
                title: "Backup",
                rows: backupRows
            ),
        ]
    }

    // MARK: - Actions

    private func editCell() -> (Row) -> Void {
        return { [weak self] sender in
            logger.info("row edit", sender.title)

            let title = sender.title
            let subtitle: String = sender.subtitle?.text ?? ""
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

            if title == "Email" {
                if MRConfig.configured {
                    // Don't change emails in the running system
                    return
                }
            }
            
            if let sender = sender as? SwitchRow {
                logger.info("got bool switch")
                let value = sender.switchValue

                switch title {
                case "E2EE enabled":
                    MRConfig.e2eeEnabled = value
                case "MDNS enabled":
                    MRConfig.mdnsEnabled = value
                case "Watch Inbox":
                    MRConfig.inboxWatch = value
                case "Watch Sentbox":
                    MRConfig.sentboxWatch = value
                case "Watch Mvbox":
                    MRConfig.mvboxWatch = value
                case "Move to Mvbox":
                    MRConfig.mvboxMove = value
                case "Save Mime Headers":
                    MRConfig.saveMimeHeaders = value
                default:
                    logger.info("unknown title", title)
                }
                return
            }

            let confirmAction = UIAlertAction(title: "Save", style: .default) { _ in
                guard let textFields = alertController.textFields,
                    textFields.count > 0 else {
                    // Could not find textfield
                    return
                }

                let field = textFields[0]

                // TODO: add field validation
                var needRefresh = false

                switch title {
                case "Email":
                    MRConfig.addr = field.text
                case "Password":
                    MRConfig.mailPw = field.text
                case "Display Name":
                    MRConfig.displayname = field.text
                    needRefresh = true
                case "Status":
                    MRConfig.selfstatus = field.text
                    needRefresh = true
                case "IMAP Server":
                    MRConfig.mailServer = field.text
                    needRefresh = true
                case "IMAP User":
                    MRConfig.mailUser = field.text
                    needRefresh = true
                case "IMAP Port":
                    MRConfig.mailPort = field.text
                    needRefresh = true
                case "SMTP Server":
                    MRConfig.sendServer = field.text
                    needRefresh = true
                case "SMTP User":
                    MRConfig.sendUser = field.text
                    needRefresh = true
                case "SMTP Port":
                    MRConfig.sendPort = field.text
                    needRefresh = true
                case "SMTP Password":
                    MRConfig.sendPw = field.text
                default:
                    logger.info("unknown title", title)
                }

                if needRefresh {
                    self?.setTable()
                    self?.tableView.reloadData()
                }
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                logger.info("canceled")
            }

            alertController.addTextField { textField in
                textField.placeholder = subtitle
            }

            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)

            self?.present(alertController, animated: true, completion: nil)
        }
    }

    private func createBackup(_: Row) {
        if let documents = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.delta.chat.ios")?.path {
            logger.info("create backup in", documents)
            dc_imex(mailboxPointer, DC_IMEX_EXPORT_BACKUP, documents, nil)
            showBackupHud("Creating Backup")
        }
    }

    private func restoreBackup(_: Row) {
        if MRConfig.configured {
            return
        }

        if let documents = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.delta.chat.ios")?.path {
            logger.info("looking for backup in", documents)

            if let file = dc_imex_has_backup(mailboxPointer, documents) {
                // Close as we are resetting the world
                dc_close(mailboxPointer)

                mailboxPointer = dc_context_new(callback_ios, nil, "iOS")
                guard mailboxPointer != nil else {
                    fatalError("Error: dc_context_new returned nil")
                }

                // TODO: open

                let hud = JGProgressHUD(style: .dark)
                hud.textLabel.text = "Restoring Backup"
                hud.show(in: view)

                dc_imex(mailboxPointer, DC_IMEX_IMPORT_BACKUP, file, nil)

                hud.dismiss(afterDelay: 1.0)
            } else {
                let alert = UIAlertController(title: "Can not restore", message: "No Backup found", preferredStyle: .alert)
                present(alert, animated: true, completion: nil)
            }
        }
    }

    private func configure(_: Row) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        showBackupHud("Configuring account")
        appDelegate.stop()
        dc_configure(mailboxPointer)

        // refresh our view
        setTable()
        tableView.reloadData()

        appDelegate.start()
    }
}
