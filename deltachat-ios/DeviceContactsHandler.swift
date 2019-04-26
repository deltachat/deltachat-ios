//
//  DeviceContactsHandler.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 26.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import Contacts
import UIKit

// MARK - ContactModel

struct DeviceContact {
	let displayName: String
	let emailAddresses: [String]
}

class DeviceContactsHandler {

	private let store = CNContactStore()


	public func getContacts() -> [DeviceContact] {
			let storedContacts = self.fetchContactsWithEmailFromDevice()
			let contacts = storedContacts.map({self.makeContact(from: $0)})
		return contacts
	}


	private func fetchContactsWithEmailFromDevice() -> [CNContact] {
		var fetchedContacts: [CNContact] = []

		// takes id from userDefaults (system settings)
		let defaultContainerId = store.defaultContainerIdentifier()
		let predicates = CNContact.predicateForContactsInContainer(withIdentifier: defaultContainerId)
		let keys = [CNContactFamilyNameKey, CNContactGivenNameKey, CNContactEmailAddressesKey]
		let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
		request.mutableObjects = true
		request.unifyResults = true
		request.sortOrder = .userDefault
		request.predicate = predicates

		do {
			try store.enumerateContacts(with: request) {(contact, error) in
				if !contact.emailAddresses.isEmpty {
					fetchedContacts.append(contact)
				}
			}
		} catch let error {
			print(error)
		}
		return fetchedContacts
	}

	private func makeContact(from contact: CNContact) -> DeviceContact {
		let rawDisplayName: String = "\(contact.givenName) \(contact.familyName)"
		let displayName = rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
		let emailAdresses = contact.emailAddresses.map({String($0.value)})
		return DeviceContact(displayName: displayName, emailAddresses: emailAdresses)
	}

	func requestDeviceContacts(delegate: DeviceContactsDelegate) {
		switch CNContactStore.authorizationStatus(for: .contacts) {
		case .authorized:
			let contacts = getContacts()
			delegate.setContacts(contacts: contacts)
		case .denied:
			delegate.accessDenied()
		case .restricted, .notDetermined:
			store.requestAccess(for: .contacts) {[unowned self] granted, error in
				if granted {
					DispatchQueue.main.async {
						let contacts = self.getContacts()
						delegate.setContacts(contacts: contacts)
					}
				} else {
					DispatchQueue.main.async {
						delegate.accessDenied()
					}
				}
			}
		}
	}

}
