//
//  AccountSetupController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 02.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class AccountSetupController: UITableViewController {

    var backupProgressObserver: Any?
    var configureProgressObserver: Any?

    lazy var hudHandler: HudHandler = {
        let hudHandler = HudHandler(parentView: self.tableView)
        return hudHandler
    }()

    lazy var emailCell:TextFieldCell = {
        let cell = TextFieldCell.makeEmailCell()
        //cell.textLabel?.text = "Email"
        //cell.inputField.placeholder = "user@example.com"
        return cell
    }()

    lazy var passwordCell:TextFieldCell = {
        let cell = TextFieldCell.makePasswordCell()
        return cell
    }()

    init() {
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Login to your server"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Login", style: .done, target: self, action: #selector(loginButtonPressed))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addProgressHudEventListener()
    }

    override func viewDidDisappear(_ animated: Bool) {
        let nc = NotificationCenter.default
        if let backupProgressObserver = self.backupProgressObserver {
            nc.removeObserver(backupProgressObserver)
        }
        if let configureProgressObserver = self.configureProgressObserver {
            nc.removeObserver(configureProgressObserver)
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        if section == 0 {
            return 2
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return "Advanced"
        } else {
            return nil
        }
    }

    /*
     override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
     if section == 0 {
     return nil
     } else {
     let label = UILabel()
     label.text = "Advanced"
     return label
     }
     }
     */

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "There are no Delta Chat servers, your data stays on your device!"
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        if row == 0 {
            return emailCell
        } else {
            return passwordCell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // handle tap on password 
        if indexPath.section == 0 && indexPath.row == 1 {
            if let emailAdress = emailCell.getText() {
               let _ = showOAuthAlertIfNeeded(emailAddress: emailAdress)
            } else {
                return 
            }
        }
    }

    @objc func loginButtonPressed() {

        guard let emailAddress = emailCell.getText() else {
            return // handle case when either email or pw fields are empty
        }

        let oAuthStarted = showOAuthAlertIfNeeded(emailAddress: emailAddress)

        if oAuthStarted {
            // the loginFlow will be handled by oAuth2
            return
        }

        let passWord = passwordCell.getText()  ?? "" // empty passwords are ok -> for oauth there is no password needed

        MRConfig.addr = emailAddress
        MRConfig.mailPw = passWord
        dc_configure(mailboxPointer)
        hudHandler.showBackupHud("Configuring account")
    }




    // returns true if needed
    private func showOAuthAlertIfNeeded(emailAddress: String) -> Bool {
        guard let oAuth2UrlPointer = dc_get_oauth2_url(mailboxPointer, emailAddress, "chat.delta:/auth") else {
            return false
        }

        let oAuth2Url = String(cString: oAuth2UrlPointer)

        // TODO: open webView with url
        if let url = URL.init(string: oAuth2Url) {
            UIApplication.shared.open(url)
            return true
        } else {
            return false
        }
    }

    private func addProgressHudEventListener() {
        let nc = NotificationCenter.default
        backupProgressObserver = nc.addObserver(
            forName: dcNotificationBackupProgress,
            object: nil,
            queue: nil
        ) {
            notification in
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
        ) {
            notification in
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
}

/*
class InputTableViewCell: UITableViewCell {
    lazy var inputField: UITextField = {
        let textField = UITextField()
        return textField
    }()

    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(inputField)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        inputField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        inputField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 100).isActive = true
        inputField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
    }
    public func getText() -> String? {
        return inputField.text
    }
}

class PasswordInputCell: UITableViewCell {
    lazy var inputField: UITextField = {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        return textField
    }()

    // TODO: to add Eye-icon -> uncomment -> add to inputField.rightView
    /*
     lazy var makeVisibleIcon: UIImageView = {
     let view = UIImageView(image: )
     return view
     }()
     */
    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView.addSubview(inputField)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        inputField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        inputField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 100).isActive = true
        inputField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
    }

    public func getText() -> String? {
        return inputField.text
    }
}

*/
