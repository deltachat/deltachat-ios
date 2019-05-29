//
//  TableViewController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 22.05.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

// this is also used as ChatDetail for SingleChats
class ContactDetailViewController: UITableViewController {
	weak var coordinator: ContactDetailCoordinatorProtocol?
	var showChatCell: Bool = false // if this is set to true it will show a "goToChat-cell"

	private enum CellIdentifiers: String {
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
		// TODO: add current notification status
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

	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editButtonPressed))
		self.title = "Contact Info"
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		tableView.reloadData()
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
		if section == 0 {
			let header = ContactDetailHeader()
			header.updateDetails(title: contact.name, subtitle: contact.email)
			if let img = contact.profileImage {
				header.setImage(img)
			} else {
				header.setBackupImage(name: contact.name, color: contact.color)
			}
			header.setVerified(isVerified: contact.isVerified)
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

	@objc private func editButtonPressed() {
		coordinator?.showEditContact(contactId: contactId)
	}
}

