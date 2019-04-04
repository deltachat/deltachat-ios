//
//  AccountSetupController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 02.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class AccountSetupController: UITableViewController {

	private var oAuthDenied:Bool = false    // if true, this will block the oAuthSetupDialogue

	private var backupProgressObserver: Any?
	private var configureProgressObserver: Any?

	private lazy var hudHandler: HudHandler = {
		let hudHandler = HudHandler(parentView: self.tableView)
		return hudHandler
	}()

	private lazy var emailCell:TextFieldCell = {
		let cell = TextFieldCell.makeEmailCell()
		cell.textField.tag = 0
		cell.textField.accessibilityIdentifier = "emailTextField"	// will be used to eventually show oAuth-Dialogue when pressing return key
		cell.textField.delegate = self
		return cell
	}()

	private lazy var passwordCell:TextFieldCell = {
		let cell = TextFieldCell.makePasswordCell()
		cell.textField.tag = 1
		cell.accessibilityIdentifier = "passwordCell"	// will be used to eventually show oAuth-Dialogue when selecting
		cell.textField.delegate = self
		return cell
	}()

	/*
	Advanced Cells:
	IMAP Server, IMAP User, IMAP Port, IMAP Security, SMTP Server, SMTP User, SMTP Port, SMTP Password, SMTP Security
	*/
	/*
	lazy var imapServerCell = TextFieldCell(description: "IMAP Server", placeholder: MRConfig.mailServer ?? MRConfig.configuredMailServer)
	lazy var imapUserCell = TextFieldCell(description: "IMAP User", placeholder: MRConfig.mailUser ?? MRConfig.configuredMailUser)
	lazy var imapPortCell = TextFieldCell(description: "IMAP Port", placeholder: MRConfig.mailPort ?? MRConfig.configuredMailPort)
	lazy var imapSecurityCell = TextFieldCell(description: "IMAP Security", placeholder: "TODO")

	lazy var smtpServerCell = TextFieldCell(description: "SMTP Server", placeholder: MRConfig.sendServer ?? MRConfig.configuredSendServer)
	lazy var smtpUserCell = TextFieldCell(description: "SMTP User", placeholder: MRConfig.sendUser ?? MRConfig.configuredSendUser)
	lazy var smtpPortCell = TextFieldCell(description: "SMTP Port", placeholder: MRConfig.sendPort ?? MRConfig.configuredSendPort)
	lazy var smtpPasswordCell = TextFieldCell(description: "SMTP Password", placeholder: "*************")
	lazy var smtpSecurityCell = TextFieldCell(description: "SMTP Security", placeholder: "TODO")
	*/


	// TODO: consider adding delegates and tags by loop - leave for now like this
	lazy var imapServerCell:TextFieldCell = {
		let cell = TextFieldCell(description: "IMAP Server", placeholder: MRConfig.mailServer ?? MRConfig.configuredMailServer)
		cell.textField.tag = 2
		cell.textField.delegate = self
		return cell
	}()

	lazy var imapUserCell:TextFieldCell = {
		let cell = TextFieldCell(description: "IMAP User", placeholder: MRConfig.mailUser ?? MRConfig.configuredMailUser)
		cell.textField.tag = 3
		cell.textField.delegate = self
		return cell
	}()

	lazy var imapPortCell:TextFieldCell = {
		let cell = TextFieldCell(description: "IMAP Port", placeholder: MRConfig.mailPort ?? MRConfig.configuredMailPort)
		cell.textField.tag = 4
		cell.textField.delegate = self
		return cell
	}()

	lazy var imapSecurityCell:TextFieldCell = {
		let cell = TextFieldCell(description: "IMAP Security", placeholder: "TODO")
		cell.textField.tag = 5
		cell.textField.delegate = self
		return cell
	}()

	lazy var smtpServerCell:TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP Server", placeholder: MRConfig.sendServer ?? MRConfig.configuredSendServer)
		cell.textField.tag = 6
		cell.textField.delegate = self
		return cell
	}()
	lazy var smtpUserCell:TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP User", placeholder: MRConfig.sendUser ?? MRConfig.configuredSendUser)
		cell.textField.tag = 7
		cell.textField.delegate = self
		return cell
	}()
	lazy var smtpPortCell:TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP Port", placeholder: MRConfig.sendPort ?? MRConfig.configuredSendPort)
		cell.textField.tag = 8
		cell.textField.delegate = self
		return cell
	}()
	lazy var smtpPasswordCell:TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP Password", placeholder: "*************")
		cell.textField.tag = 9
		cell.textField.delegate = self
		return cell
	}()
	lazy var smtpSecurityCell:TextFieldCell = {
		let cell = TextFieldCell(description: "SMTP Security", placeholder: "TODO")
		cell.textField.tag = 10
		cell.textField.delegate = self
		return cell
	}()

	// this loginButton can be enabled and disabled
	let loginButton:UIBarButtonItem = UIBarButtonItem(title: "Login", style: .done, target: self, action: #selector(loginButtonPressed))


	private lazy var basicSectionCells:[UITableViewCell] = [emailCell, passwordCell]
	private lazy var advancedSectionCells:[UITableViewCell] = [imapServerCell,imapUserCell,imapPortCell,imapSecurityCell,smtpServerCell,smtpUserCell,smtpPortCell,smtpPasswordCell,smtpSecurityCell]

	private var advancedSectionShowing: Bool = false

	init() {
		super.init(style: .grouped)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		self.title = "Login to your server"
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeButtonPressed))
		self.navigationItem.rightBarButtonItem = loginButton
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		addProgressHudEventListener()
		//loginButton.isEnabled = false
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
			return basicSectionCells.count
		} else {
			return advancedSectionShowing ? advancedSectionCells.count : 0
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 1 {
			return "Advanced"
		} else {
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {

		if section == 1 {
			// Advanced Header
			let advancedView = AdvancedSectionHeader()
			advancedView.handleTap = toggleAdvancedSection
			// set tapHandler
			return advancedView

		} else {
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 36.0
	}

	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 0 {
			return "There are no Delta Chat servers, your data stays on your device!"
		} else {
			return "For known email providers additional settings are setup automatically. Sometimes IMAP needs to be enabled in the web frontend. Consult your email provider or friends for help"
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = indexPath.section
		let row = indexPath.row

		if section == 0 {
			// basicSection
			return basicSectionCells[row]
		} else {
			// advancedSection
			return advancedSectionCells[row]
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		// handle tap on password -> show eventuall oAuthDialogue
		if let cell = tableView.cellForRow(at: indexPath) as? TextFieldCell {
			if cell.accessibilityIdentifier == "passwordCell" {
				if let emailAdress = cell.getText() {
					_ = showOAuthAlertIfNeeded(emailAddress: emailAdress, handleCancel: nil)
				}
			}
		}
	}

	private func toggleAdvancedSection(button: UIButton) {

		let willShow = !self.advancedSectionShowing

		// extract indexPaths from advancedCells
		let advancedIndexPaths:[IndexPath] = advancedSectionCells.indices.map({IndexPath(row: $0, section: 1)})

		//advancedSectionCells.indices.map({indexPaths.append(IndexPath(row: $0, section: 1))}

		// set flag before delete/insert operation, because cellForRowAt will be triggered and uses this flag
		self.advancedSectionShowing = willShow

		button.setTitle(willShow ? "Hide":"Show", for: .normal)

		if willShow {
			tableView.insertRows(at: advancedIndexPaths, with: .fade)
		} else {
			tableView.deleteRows(at: advancedIndexPaths, with: .fade)

		}

	}

	@objc func loginButtonPressed() {

		guard let emailAddress = emailCell.getText() else {
			return // handle case when either email or pw fields are empty
		}

		let oAuthStarted = showOAuthAlertIfNeeded(emailAddress: emailAddress, handleCancel: nil)

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

	@objc func closeButtonPressed() {
		dismiss(animated: true, completion: nil)
	}

	// returns true if needed
	private func showOAuthAlertIfNeeded(emailAddress: String, handleCancel: (()->())?) -> Bool {
		if oAuthDenied {
			return false
		}

		guard let oAuth2UrlPointer = dc_get_oauth2_url(mailboxPointer, emailAddress, "chat.delta:/auth") else {
			return false
		}

		let oAuth2Url = String(cString: oAuth2UrlPointer)

		if let url = URL.init(string: oAuth2Url)  {
			let oAuthAlertController = UIAlertController(title: "You can use oAuth", message: "Click confirm if you want to use oAuth", preferredStyle: .alert)
			let confirm = UIAlertAction(title: "Confirm", style: .default, handler: {
				_ in
				self.launchOAuthBrowserWindow(url: url)
			})
			let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: {
				_ in
				self.oAuthDenied = true
				handleCancel?()
			})
			oAuthAlertController.addAction(confirm)
			oAuthAlertController.addAction(cancel)

			present(oAuthAlertController, animated: true, completion: nil)
			return true
		} else {
			return false
		}
	}

	private func launchOAuthBrowserWindow(url: URL) {
		UIApplication.shared.open(url)
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

extension AccountSetupController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let currentTag = textField.tag

		if textField.accessibilityIdentifier == "emailTextField" {
			// special case: email field should check for potential oAuth
			showOAuthAlertIfNeeded(emailAddress: textField.text ?? "", handleCancel: {
				// this will activate passwordTextField if oAuth-Dialogue was canceled
				self.passwordCell.textField.becomeFirstResponder()
			})
		} else {
			if let nextField = tableView.viewWithTag(currentTag + 1) as? UITextField {
				if nextField.tag > 1 && !advancedSectionShowing {
					// gets here when trying to activate a collapsed cell
					return false
				}
				nextField.becomeFirstResponder()
			}
		}

		return false
	}
}

class AdvancedSectionHeader: UIView {

	var handleTap:((UIButton) -> ())?

	private var label:UILabel = {
		let label = UILabel()
		label.text = "ADVANCED"
		label.font = UIFont.systemFont(ofSize: 15)
		label.textColor = UIColor.darkGray
		return label
	}()

	private var toggleButton:UIButton = {
		let button = UIButton(type: .system)
		button.setTitle("Show", for: .normal)
		button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside )
		//button.target(forAction: #selector(buttonTapped(_:)), withSender: self)
		return button
	}()

	init() {
		super.init(frame: .zero)    // will be constraint from tableViewDelegate
		setupSubviews()
		let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped)) // use this if the whole header is supposed to be clickable
		self.addGestureRecognizer(tap)

	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setupSubviews() {
		self.addSubview(label)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant:  15).isActive = true
		label.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 0).isActive = true
		self.addSubview(toggleButton)
		toggleButton.translatesAutoresizingMaskIntoConstraints = false

		toggleButton.leadingAnchor.constraint(equalTo: self.trailingAnchor, constant: -60).isActive = true	// since button will change title it should be left aligned
		toggleButton.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: 0).isActive = true
	}

	@objc func buttonTapped(_ button: UIButton) {
		handleTap?(button)
	}

	@objc func viewTapped() {
		handleTap?(self.toggleButton)
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
