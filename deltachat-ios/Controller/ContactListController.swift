//
//  ContactListController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit
import Contacts

class ContactListController: UITableViewController {
  weak var coordinator: ContactListCoordinator?

  let contactCellReuseIdentifier = "ChatCell"
  var contactIds: [Int] = Utils.getContactIds()
  var contactIdsForGroup: Set<Int> = []

	lazy var deviceContactHandler: DeviceContactsHandler = {
		let handler = DeviceContactsHandler()
		handler.contactListDelegate = self
		return handler
	}()

	lazy var newContactButton: UIBarButtonItem = {
		let button = UIBarButtonItem(image: #imageLiteral(resourceName: "ic_add").withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(newContactButtonPressed))
		return button
	}()

	var deviceContactAccessGranted: Bool = false {
		didSet {
			tableView.reloadData()
		}
	}

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Contacts"
    navigationController?.navigationBar.prefersLargeTitles = true

   // tableView.rowHeight = 80
    tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
		tableView.register(ActionCell.self, forCellReuseIdentifier: "actionCell")

		navigationItem.rightBarButtonItem = newContactButton
  }

  private func getContactIds() {
    contactIds = Utils.getContactIds()
    tableView.reloadData()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if #available(iOS 11.0, *) {
      navigationController?.navigationBar.prefersLargeTitles = true
    }
		deviceContactHandler.importDeviceContacts()
		deviceContactAccessGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    getContactIds()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if #available(iOS 11.0, *) {
      navigationController?.navigationBar.prefersLargeTitles = false
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }

  override func numberOfSections(in _: UITableView) -> Int {
		return deviceContactAccessGranted ? 1 : 2
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
		if !deviceContactAccessGranted && section == 0 {
			return 1
		}
    return contactIds.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = indexPath.section

		if !deviceContactAccessGranted && section == 0 {
			let cell: ActionCell
			if let c = tableView.dequeueReusableCell(withIdentifier: "actionCell") as? ActionCell {
				cell = c
			} else {
				cell = ActionCell(style: .default, reuseIdentifier: "actionCell")
			}
			cell.actionTitle = "Import Device Contacts"
			return cell
		} else {

		let cell: ContactCell
    if let c = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier) as? ContactCell {
      cell = c
    } else {
      cell = ContactCell(style: .subtitle, reuseIdentifier: contactCellReuseIdentifier)
    }
    let row = indexPath.row
    let contactRow = row

    if contactRow < contactIds.count {
      let contact = MRContact(id: contactIds[contactRow])
      cell.nameLabel.text = contact.name
      cell.emailLabel.text = contact.email

      cell.selectionStyle = .none

      if let img = contact.profileImage {
        cell.setImage(img)
      } else {
        cell.setBackupImage(name: contact.name, color: contact.color)
      }
      cell.setVerified(isVerified: contact.isVerified)
    }
    return cell
		}
  }

  override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
		if !deviceContactAccessGranted && indexPath.section == 0 {
			showSettingsAlert()
		} else {
			let contactId = contactIds[indexPath.row]
			let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))

			coordinator?.showChat(chatId: Int(chatId))
			// coordinator?.showContactDetail(contactId: contactId)
		}
	}

	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		let row = indexPath.row

		let contactId = contactIds[row]

		// assigning swipe by delete to chats
		let edit = UITableViewRowAction(style: .default, title: "Edit") {
			[unowned self] _, indexPath in
			self.coordinator?.showContactDetail(contactId: contactId)
		}
		edit.backgroundColor = DCColors.primary
		return [edit]
	}

	@objc func newContactButtonPressed() {
		coordinator?.showNewContactController()
	}
}

extension ContactListController: ContactListDelegate {
	func deviceContactsImported() {
		contactIds = Utils.getContactIds()
	}

	func accessGranted() {
		deviceContactAccessGranted = true
	}

	func accessDenied() {
		deviceContactAccessGranted = false
		getContactIds()
	}

	private func showSettingsAlert() {
		let alert = UIAlertController(
			title: "Import Contacts from to your device",
			message: "To chat with contacts from your device open the settings menu and enable the Contacts option",
			preferredStyle: .alert
		)
		alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
			UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
		})
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
		})
		present(alert, animated: true)
	}
}
