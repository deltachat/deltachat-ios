//
//  TableViewController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 22.05.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class ContactDetailViewController: UITableViewController {
	weak var coordinator: ContactDetailCoordinator?
	var showChatCell: Bool = false // if this is set to true it will show a "goToChat-cell"

	private enum CellIdentifiers: String  {
		case notification = "notificationCell"
		case block = "blockContactCell"
		case chat = "chatCell"
	}

	private let contactId: Int

	private var contact: MRContact {
		return MRContact(id: contactId)
	}

	private var notificationsCell: UITableViewCell = {
		let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
		cell.textLabel?.text = "Notifications"
		cell.accessibilityIdentifier = CellIdentifiers.notification.rawValue
		cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
		cell.selectionStyle = .none
		// TODO: add notification status
		return cell
	}()

	private lazy var chatCell: ActionCell = {
		let cell = ActionCell()
		cell.accessibilityIdentifier = CellIdentifiers.chat.rawValue
		cell.actionColor = SystemColor.blue.uiColor
		cell.actionTitle = "Chat with \(contact.name)"
		cell.selectionStyle = .none
		return cell
	}()

	private lazy var blockContactCell: ActionCell = {
		let cell = ActionCell()
		cell.accessibilityIdentifier = CellIdentifiers.block.rawValue
		cell.actionTitle = contact.isBlocked ? "Unblock Contact" : "Block Contact"
		cell.actionColor = contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
		cell.selectionStyle = .none
		return cell
	}()



	init(contactId: Int) {
		self.contactId = contactId
		super.init(style: .grouped)
	}

	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return showChatCell ? 2 : 1
		} else if section == 1 {
			return 1
		}
		return 0
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = indexPath.section
		let row = indexPath.row

		if section == 0 {
			if row == 0 {
				return notificationsCell
			} else {
				return chatCell
			}
		} else {
			return blockContactCell
		}

	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let cell = tableView.cellForRow(at: indexPath) else {
			return
		}

		if let identifier = CellIdentifiers(rawValue: cell.accessibilityIdentifier ?? "") {
			switch identifier {
			case .block:
				toggleBlockContact()
			case .chat:
				let chatId = Int(dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId)))
				coordinator?.showChat(chatId: chatId)
			case .notification:
				showNotificationSetup()
			}
		}
	}

	override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)
		if section == 0 {
			let contactCell = ContactCell()
			contactCell.backgroundColor = bg
			contactCell.nameLabel.text = contact.name
			contactCell.emailLabel.text = contact.email
			contactCell.darkMode = false
			contactCell.selectionStyle = .none
			if let img = contact.profileImage {
				contactCell.setImage(img)
			} else {
				contactCell.setBackupImage(name: contact.name, color: contact.color)
			}
			contactCell.setVerified(isVerified: contact.isVerified)
			return contactCell
		}
		return nil
	}

	private func toggleBlockContact() {
		contact.isBlocked ? contact.unblock() : contact.block()
		updateBlockContactCell()
	}

	private func updateBlockContactCell() {
		blockContactCell.actionTitle = contact.isBlocked ? "Unblock Contact" : "Block Contact"
		blockContactCell.actionColor = contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red
	}

	private func showNotificationSetup() {
		let notificationSetupAlert = UIAlertController(title: "Notifications Setup is not implemented yet", message: "But you get an idea where this is going", preferredStyle: .actionSheet)
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		notificationSetupAlert.addAction(cancelAction)
		present(notificationSetupAlert, animated: true, completion: nil)
	}







	/*
	override func viewDidLoad() {
	super.viewDidLoad()
	title = "Info"
	}

	override func viewWillAppear(_: Bool) {
	navigationController?.navigationBar.prefersLargeTitles = false
	tableView.reloadData()
	}

	override func didReceiveMemoryWarning() {
	super.didReceiveMemoryWarning()
	// Dispose of any resources that can be recreated.
	}

	// MARK: - Table view data source

	override func numberOfSections(in _: UITableView) -> Int {
	return 1
	}

	override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
	if section == 0 {
	return 3
	}

	return 0
	}

	override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
	let row = indexPath.row

	let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

	let settingsImage = #imageLiteral(resourceName: "baseline_settings_black_18pt").withRenderingMode(.alwaysTemplate)
	cell.imageView?.image = settingsImage
	cell.imageView?.tintColor = UIColor.clear

	if row == 0 {
	cell.textLabel?.text = "Settings"
	cell.imageView?.tintColor = UIColor.gray
	}
	if row == 1 {
	cell.textLabel?.text = "Edit name"
	}

	if row == 2 {
	cell.textLabel?.text = "New chat"
	}
	return cell
	}

	override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
	let row = indexPath.row

	if row == 0 {
	let alert = UIAlertController(title: "Not implemented", message: "Settings are not implemented yet.", preferredStyle: .alert)
	alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
	present(alert, animated: true, completion: nil)
	}
	if row == 1 {
	let newContactController = NewContactController(contactIdForUpdate: contactId)
	navigationController?.pushViewController(newContactController, animated: true)
	}
	if row == 2 {
	displayNewChat(contactId: contactId)
	}
	}

	override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
	return 80
	}

	override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
	let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)
	if section == 0 {
	let contactCell = ContactCell()
	contactCell.backgroundColor = bg
	contactCell.nameLabel.text = contact.name
	contactCell.emailLabel.text = contact.email
	contactCell.darkMode = false
	contactCell.selectionStyle = .none
	if let img = contact.profileImage {
	contactCell.setImage(img)
	} else {
	contactCell.setBackupImage(name: contact.name, color: contact.color)
	}
	contactCell.setVerified(isVerified: contact.isVerified)
	return contactCell
	}

	let vw = UIView()
	vw.backgroundColor = bg

	return vw
	}

	private func displayNewChat(contactId: Int) {
	let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
	coordinator?.showChat(chatId: Int(chatId))
	}

	*/
}
