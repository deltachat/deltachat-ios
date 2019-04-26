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


	private func makeContactString(contacts: [CNContact]) -> String {
		var contactString:String = ""
		for contact in contacts {
			let displayName: String = "\(contact.givenName) \(contact.familyName)"
			// cnContact can have multiple email addresses -> create contact for each email address
			for emailAddress in contact.emailAddresses {
				contactString += "\(displayName)\n\(emailAddress.value)\n"
			}
		}
		return contactString
	}

	private func getContacts() -> String {
			let storedContacts = self.fetchContactsWithEmailFromDevice()
			return makeContactString(contacts: storedContacts)
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

	func importDeviceContacts(delegate: DeviceContactsDelegate) {
		switch CNContactStore.authorizationStatus(for: .contacts) {
		case .authorized:
			let contactString = getContacts()
			delegate.setContacts(contactString: contactString)
		case .denied:
			delegate.accessDenied()
		case .restricted, .notDetermined:
			store.requestAccess(for: .contacts) {[unowned self] granted, error in
				if granted {
					DispatchQueue.main.async {
						let contactString = self.getContacts()
						delegate.setContacts(contactString: contactString)
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
