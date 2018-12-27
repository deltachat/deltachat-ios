//
//  SettingsController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit
import MessageKit
import MessageInputBar
import QuickTableViewController
import JGProgressHUD

final internal class SettingsViewController: QuickTableViewController {
    let documentInteractionController = UIDocumentInteractionController()

    // MARK: - Properties

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"

        documentInteractionController.delegate = self as? UIDocumentInteractionControllerDelegate
        setTable()
    }

    private func setTable() {
        tableContents = [
          Section(
            title: "Basics",
            rows: [
              NavigationRow(title: "Email", subtitle: .rightAligned(MRConfig.addr ?? ""), action: editCell()),
              NavigationRow(title: "Password", subtitle: .rightAligned("********"), action: editCell()),
            ]),

          Section(
            title: "User Details",
            rows: [
              NavigationRow(title: "Display Name", subtitle: .rightAligned(MRConfig.displayname ?? ""), action: editCell()),
              NavigationRow(title: "Status", subtitle: .rightAligned(MRConfig.selfstatus ?? ""), action: editCell()),
            ]),

          Section(
            title: "Advanced",
            rows: [
              NavigationRow(title: "IMAP Server", subtitle: .rightAligned(MRConfig.mailServer ?? ""), action: editCell()),
              NavigationRow(title: "IMAP User", subtitle: .rightAligned(MRConfig.mailUser ?? ""), action: editCell()),
              NavigationRow(title: "IMAP Port", subtitle: .rightAligned(MRConfig.mailPort ?? ""), action: editCell()),
       
              NavigationRow(title: "SMTP Server", subtitle: .rightAligned(MRConfig.sendServer ?? ""), action: editCell()),
              NavigationRow(title: "SMTP User", subtitle: .rightAligned(MRConfig.sendUser ?? ""), action: editCell()),
              NavigationRow(title: "SMTP Port", subtitle: .rightAligned(MRConfig.sendPort ?? ""), action: editCell()),
              NavigationRow(title: "SMTP Password", subtitle: .rightAligned("********"), action: editCell()),
              ]),
          
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
            ]),

          Section(
            title: "Backups",
            rows: [
              TapActionRow(title: "Create backup", action: { [weak self] in self?.createBackup($0) }),
              TapActionRow(title: "Restore from backup", action: { [weak self] in self?.restoreBackup($0) })
            ]),
        ]
    }

    // MARK: - Actions

    private func editCell() -> (Row) -> Void {
        return { [weak self] sender in
            print("row edit", sender.title)

            let title = sender.title
            let subtitle: String = sender.subtitle?.text ?? ""
            let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

            if let sender = sender as? SwitchRow {
                print("got bool switch")
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
                    print("unknown title", title)
                }
                return
            }

            let confirmAction = UIAlertAction(title: "Save", style: .default) { (_) in
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
                    needRefresh = true
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
                    print("unknown title", title)
                }

                if needRefresh {
                    self?.setTable()
                    self?.tableView.reloadData()
                }
            }

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
                print("canceled")
            }

            alertController.addTextField { (textField) in
                textField.placeholder = subtitle
            }

            alertController.addAction(confirmAction)
            alertController.addAction(cancelAction)

            self?.present(alertController, animated: true, completion: nil)
        }
    }

    private func createBackup(_ sender: Row) {
        if let documents = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.delta.chat.ios")?.path {
            print("create backup in", documents)
            dc_imex(mailboxPointer, DC_IMEX_EXPORT_BACKUP, documents, nil)

            let hud = JGProgressHUD(style: .dark)
            hud.textLabel.text = "Creating Backup"
            hud.show(in: self.view)

            // TODO: dismiss when actually done
            hud.dismiss(afterDelay: 2.0)
        }
    }

    private func restoreBackup(_ sender: Row) {
        if let documents = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.delta.chat.ios")?.path {
            print("looking for backup in", documents)

            if let file = dc_imex_has_backup(mailboxPointer, documents) {
                // Close as we are resetting the world
                dc_close(mailboxPointer)

                mailboxPointer = dc_context_new(callback_ios, nil, "iOS")
                guard mailboxPointer != nil else {
                    fatalError("Error: dc_context_new returned nil")
                }

                dc_imex(mailboxPointer, DC_IMEX_IMPORT_BACKUP, file, nil)

                let hud = JGProgressHUD(style: .dark)
                hud.textLabel.text = "Restoring Backup"
                hud.show(in: self.view)

                // TODO: dismiss when actually done
                hud.dismiss(afterDelay: 2.0)
            } else {
                let alert = UIAlertController(title: "Can not restore", message: "No Backup found", preferredStyle: .alert)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}
