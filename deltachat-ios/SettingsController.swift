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

        tableContents = [
          Section(
            title: "Basics",
            rows: [
              NavigationRow(title: "Email", subtitle: .rightAligned(MRConfig.addr ?? ""), action: { _ in }),
              NavigationRow(title: "Password", subtitle: .rightAligned("********"), action: { _ in }),
            ]),

          Section(
            title: "User Details",
            rows: [
              NavigationRow(title: "Display Name", subtitle: .rightAligned(MRConfig.displayname ?? ""), action: { _ in }),
              NavigationRow(title: "Status", subtitle: .rightAligned(MRConfig.selfstatus ?? ""), action: { _ in }),
            ]),

          Section(
            title: "Advanced",
            rows: [
              NavigationRow(title: "Server", subtitle: .rightAligned(MRConfig.mailServer ?? ""), action: { _ in }),
              NavigationRow(title: "User", subtitle: .rightAligned(MRConfig.mailUser ?? ""), action: { _ in }),
              NavigationRow(title: "Port", subtitle: .rightAligned(MRConfig.mailPort ?? ""), action: { _ in }),
              NavigationRow(title: "Send Server", subtitle: .rightAligned(MRConfig.sendServer ?? ""), action: { _ in }),
              NavigationRow(title: "Send User", subtitle: .rightAligned(MRConfig.sendUser ?? ""), action: { _ in }),
              NavigationRow(title: "Send Port", subtitle: .rightAligned(MRConfig.sendPort ?? ""), action: { _ in }),
              NavigationRow(title: "Send Password", subtitle: .rightAligned("********"), action: { _ in }),

            ]),

          Section(
            title: "Flags",
            rows: [
              SwitchRow(title: "E2EE enabled", switchValue: MRConfig.e2eeEnabled, action: { _ in }),
              SwitchRow(title: "MDNS enabled", switchValue: MRConfig.mdnsEnabled, action: { _ in }),
              SwitchRow(title: "Watch Inbox", switchValue: MRConfig.inboxWatch, action: { _ in }),
              SwitchRow(title: "Watch Sentbox", switchValue: MRConfig.sentboxWatch, action: { _ in }),
              SwitchRow(title: "Watch Mvbox", switchValue: MRConfig.mvboxWatch, action: { _ in }),
              SwitchRow(title: "Move to Mvbox", switchValue: MRConfig.mvboxMove, action: { _ in }),
              SwitchRow(title: "Save Mime Headers", switchValue: MRConfig.saveMimeHeaders, action: { _ in }),
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
