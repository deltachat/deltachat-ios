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

	private lazy var searchController: UISearchController = {
		let searchController = UISearchController(searchResultsController: nil)
		searchController.searchResultsUpdater = self
		searchController.obscuresBackgroundDuringPresentation = false
		searchController.searchBar.placeholder = "Search Contact"
		return searchController
	}()

	// contactWithSearchResults.indexesToHightLight empty by default
	var contacts: [ContactWithSearchResults] {
		return contactIds.map { ContactWithSearchResults(contact: MRContact(id: $0), indexesToHighlight: []) }
	}

	// used when seachbar is active
	var filteredContacts: [ContactWithSearchResults] = []

	// searchBar active?
	func isFiltering() -> Bool {
		return searchController.isActive && !searchBarIsEmpty()
	}

	let contactCellReuseIdentifier = "ChatCell"
	var contactIds: [Int] = Utils.getContactIds()
	var contactIdsForGroup: Set<Int> = []

	lazy var deviceContactHandler: DeviceContactsHandler = {
		let handler = DeviceContactsHandler()
		handler.contactListDelegate = self
		return handler
	}()

	lazy var newContactButton: UIBarButtonItem = {
		let button = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(newContactButtonPressed))
		// UIBarButtonItem(image: #imageLiteral(resourceName: "ic_add").withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(newContactButtonPressed))
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
		navigationItem.searchController = searchController
		tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
		tableView.register(ActionCell.self, forCellReuseIdentifier: "actionCell")

		navigationItem.rightBarButtonItem = newContactButton
	}

	private func getContactIds() {
		contactIds = Utils.getContactIds()
		tableView.reloadData()
	}

	private func searchBarIsEmpty() -> Bool {
		return searchController.searchBar.text?.isEmpty ?? true
	}

	private func filterContentForSearchText(_ searchText: String, scope _: String = "All") {
		let contactsWithHighlights: [ContactWithSearchResults] = contacts.map { contact in
			let indexes = contact.contact.contains(searchText: searchText)
			return ContactWithSearchResults(contact: contact.contact, indexesToHighlight: indexes)
		}

		filteredContacts = contactsWithHighlights.filter { !$0.indexesToHighlight.isEmpty }
		tableView.reloadData()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if #available(iOS 11.0, *) {
			navigationController?.navigationBar.prefersLargeTitles = true
		}
		deviceContactHandler.importDeviceContacts()
		deviceContactAccessGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
		searchController.searchBar.text = nil
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
		return isFiltering() ? filteredContacts.count : contactIds.count
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
				let contact: ContactWithSearchResults = isFiltering() ? filteredContacts[contactRow] : contacts[contactRow]
				updateContactCell(cell: cell, contactWithHighlight: contact)
				cell.selectionStyle = .none

				cell.setVerified(isVerified: contact.contact.isVerified)
			}
			return cell
		}
	}

	override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
		let row = indexPath.row
		if !deviceContactAccessGranted && indexPath.section == 0 {
			showSettingsAlert()
		} else {
			let contactId = isFiltering() ? filteredContacts[row].contact.id : contactIds[row]
			let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
			searchController.dismiss(animated: false) {
				self.coordinator?.showChat(chatId: Int(chatId))
			}
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

	private func updateContactCell(cell: ContactCell, contactWithHighlight: ContactWithSearchResults) {
		let contact = contactWithHighlight.contact

		if let nameHighlightedIndexes = contactWithHighlight.indexesToHighlight.filter({ $0.contactDetail == .NAME }).first,
			let emailHighlightedIndexes = contactWithHighlight.indexesToHighlight.filter({ $0.contactDetail == .EMAIL }).first {
			// gets here when contact is a result of current search -> highlights relevant indexes
			let nameLabelFontSize = cell.nameLabel.font.pointSize
			let emailLabelFontSize = cell.emailLabel.font.pointSize

			cell.nameLabel.attributedText = contact.name.boldAt(indexes: nameHighlightedIndexes.indexes, fontSize: nameLabelFontSize)
			cell.emailLabel.attributedText = contact.email.boldAt(indexes: emailHighlightedIndexes.indexes, fontSize: emailLabelFontSize)
		} else {
			cell.nameLabel.text = contact.name
			cell.emailLabel.text = contact.email
		}
		cell.initialsLabel.text = Utils.getInitials(inputName: contact.name)
		cell.setColor(contact.color)
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

extension ContactListController: UISearchResultsUpdating {
	func updateSearchResults(for searchController: UISearchController) {
		if let searchText = searchController.searchBar.text {
			filterContentForSearchText(searchText)
		}
	}
}
