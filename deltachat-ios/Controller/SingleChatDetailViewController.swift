//
//  ChatDetailViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 04.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class ChatDetailViewController: UIViewController {
	weak var coordinator: ChatDetailCoordinator?

	fileprivate var chat: MRChat
	var chatDetailTable: UITableView = {
		let table = UITableView(frame: .zero, style: .grouped)
		table.bounces = false
		table.register(UITableViewCell.self, forCellReuseIdentifier: "tableCell")
		table.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
		table.register(ContactCell.self, forCellReuseIdentifier: "contactCell")
		return table
	}()

	init(chatId: Int) {
		self.chat = MRChat(id: chatId)
		super.init(nibName: nil, bundle: nil)
		setupSubviews()
	}


	override func viewWillAppear(_ animated: Bool) {
		chatDetailTable.reloadData()	// to display updates
	}

	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupSubviews() {
		view.addSubview(chatDetailTable)
		chatDetailTable.translatesAutoresizingMaskIntoConstraints = false

		chatDetailTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		chatDetailTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
		chatDetailTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		chatDetailTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
	}

	@objc func editButtonPressed() {
		// will be overwritten
	}

	func showNotificationSetup() {
		let notificationSetupAlert = UIAlertController(title: "Notifications Setup is not implemented yet", message: "But you get an idea where this is going", preferredStyle: .actionSheet)
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		notificationSetupAlert.addAction(cancelAction)
		present(notificationSetupAlert, animated: true, completion: nil)
	}

}

class SingleChatDetailViewController: ChatDetailViewController {

	var contact: MRContact? {
		if let id = chat.contactIds.first {
			return MRContact(id: id)
		}
		return nil
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Info"
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editButtonPressed))
		chatDetailTable.delegate = self
		chatDetailTable.dataSource = self

	}

	@objc override func editButtonPressed() {
		if let id = chat.contactIds.first {
			coordinator?.showSingleChatEdit(contactId: id)
		}
	}

}

extension SingleChatDetailViewController: UITableViewDelegate, UITableViewDataSource {

	func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			guard let contact = contact else {
				return nil
			}
			let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)

			let contactCell = ContactCell()
			contactCell.backgroundColor = bg
			contactCell.nameLabel.text = contact.name
			contactCell.emailLabel.text = contact.email
			contactCell.darkMode = false
			contactCell.selectionStyle = .none
			if let img = chat.profileImage {
				contactCell.setImage(img)
			} else {
				contactCell.setBackupImage(name: contact.name, color: contact.color)
			}
			contactCell.setVerified(isVerified: chat.isVerified)
			return contactCell
		} else {
			return nil
		}
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = indexPath.section

		if section == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath)
			cell.textLabel?.text = "Notifications"
			return cell
		} else if section == 1 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath) as! ActionCell
			if let contact = contact {
				cell.actionTitle =  contact.isBlocked ? "Unblock Contact" : "Block Contact"
				cell.actionColor = contact.isBlocked ? SystemColor.blue.uiColor : UIColor.red // SystemColor.red.uiColor
			}
			return cell
		}
		return UITableViewCell(frame: .zero)
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let section = indexPath.section

		if section == 0 {
			showNotificationSetup()
		} else if section == 1 {
			if let contact = contact {
				contact.isBlocked ? contact.unblock() : contact.block()
				tableView.reloadData()
			}
		}
	}
}

class GroupChatDetailViewController: ChatDetailViewController {

//	var currentUserChatId:
	let editGroupCell = GroupLabelCell()


	var editingGroupName: Bool = false
	lazy var editBarButtonItem: UIBarButtonItem = {
		UIBarButtonItem(title: editingGroupName ? "Done" : "Edit", style: .plain, target: self, action: #selector(editButtonPressed))
	}()

	var groupMembers: [MRContact] {
		let ids = chat.contactIds
		return ids.map({MRContact(id: $0)})
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Group Info"
		chatDetailTable.delegate = self
		chatDetailTable.dataSource = self
		navigationItem.rightBarButtonItem = editBarButtonItem
	}

	@objc override func editButtonPressed() {
		if editingGroupName {
			let newName = editGroupCell.getGroupName()
			dc_set_chat_name(mailboxPointer, UInt32(chat.id), newName)
			self.chat = MRChat(id: chat.id) // reload
		}

		editingGroupName = !editingGroupName
		editBarButtonItem.title = editingGroupName ? "Save" : "Edit"
		chatDetailTable.reloadData()
	}
}

extension GroupChatDetailViewController: UITableViewDelegate, UITableViewDataSource {

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 1 {
			return "Members:"
		}
		return nil
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)

			if editingGroupName {
				editGroupCell.groupBadge.setColor(chat.color)
				editGroupCell.backgroundColor = bg
				editGroupCell.inputField.text = chat.name
				editGroupCell.groupBadge.setText(chat.name)
				return editGroupCell
			} else {

				let contactCell = ContactCell()
				contactCell.backgroundColor = bg
				contactCell.nameLabel.text = chat.name
				contactCell.emailLabel.text = chat.subtitle
				contactCell.darkMode = false
				contactCell.selectionStyle = .none
				if let img = chat.profileImage {
					contactCell.setImage(img)
				} else {
					contactCell.setBackupImage(name: chat.name, color: chat.color)
				}
				contactCell.setVerified(isVerified: chat.isVerified)
				return contactCell
			}
		} else {
			return nil
		}
	}

	func numberOfSections(in tableView: UITableView) -> Int {
		return 3
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return 1
		} else if section == 1 {
			return groupMembers.count
		} else if section == 2 {
			return 1
		} else {
			return 0
		}
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = indexPath.section
		let row = indexPath.row

		if section == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell", for: indexPath)
			cell.textLabel?.text = "Notifications"
			return cell
		} else  if section == 1 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "contactCell", for: indexPath) as! ContactCell
			let contact = groupMembers[row]
			cell.nameLabel.text = contact.name
			cell.emailLabel.text = contact.email
			cell.initialsLabel.text = Utils.getInitials(inputName: contact.name)
			cell.setColor(contact.color)
			return cell
		} else if section == 2 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath) as! ActionCell
			cell.actionTitle = "Leave Group"
			cell.actionColor = UIColor.red
			return cell
		}

		return UITableViewCell(frame: .zero)
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let section = indexPath.section
		let row = indexPath.row
		if section == 0 {
			showNotificationSetup()
		} else if section == 1 {
			// ignore for now - in Telegram tapping a contactCell leads into ContactDetail
		} else if section == 2 {
			// leave group

		}
	}
}





