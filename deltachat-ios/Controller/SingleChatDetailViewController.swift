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

	fileprivate let chat: MRChat
	var chatDetailTable: UITableView = {
		let table = UITableView(frame: .zero, style: .grouped)
		table.bounces = false
		table.register(UITableViewCell.self, forCellReuseIdentifier: "tableCell")
		table.register(ActionCell.self, forCellReuseIdentifier: "actionCell")
		return table
	}()

	init(chatId: Int) {
		self.chat = MRChat(id: chatId)
		super.init(nibName: nil, bundle: nil)
		setupSubviews()
	}

	override func viewDidLoad() {
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editButtonPressed))
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

	func setupNotifications() {
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
			setupNotifications()
		} else if section == 1 {
			if let contact = contact {
				contact.isBlocked ? contact.unblock() : contact.block()
				tableView.reloadData()
			}
		}
	}
}


class GroupChatDetailViewController: ChatDetailViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Group Info"
		chatDetailTable.delegate = self
		chatDetailTable.dataSource = self
	}
}

extension GroupChatDetailViewController: UITableViewDelegate, UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 0
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return UITableViewCell(frame: .zero)
	}


}





