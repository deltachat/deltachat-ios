//
//  DeviceContactsHandler.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 26.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import Contacts
import UIKit

class DeviceContactsHandler {
  private let store = CNContactStore()

  private func makeContactString(contacts: [CNContact]) -> String {
    var contactString: String = ""
    for contact in contacts {
      let displayName: String = "\(contact.givenName) \(contact.familyName)"
      // cnContact can have multiple email addresses -> create contact for each email address
      for emailAddress in contact.emailAddresses {
        contactString += "\(displayName)\n\(emailAddress.value)\n"
      }
    }
    return contactString
  }

  private func addContactsToCore() {
    let storedContacts = fetchContactsWithEmailFromDevice()
    let contactString = makeContactString(contacts: storedContacts)
    dc_add_address_book(mailboxPointer, contactString)
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
      try store.enumerateContacts(with: request) { contact, _ in
        if !contact.emailAddresses.isEmpty {
          fetchedContacts.append(contact)
        }
      }
    } catch {
      print(error)
    }
    return fetchedContacts
  }

  public func importDeviceContacts(delegate: DeviceContactsDelegate?) {
    switch CNContactStore.authorizationStatus(for: .contacts) {
    case .authorized:
      addContactsToCore()
      delegate?.accessGranted()
    case .denied:
      delegate?.accessDenied()
    case .restricted, .notDetermined:
      store.requestAccess(for: .contacts) { [unowned self] granted, _ in
        if granted {
          DispatchQueue.main.async {
            self.addContactsToCore()
            delegate?.accessGranted()
          }
        } else {
          DispatchQueue.main.async {
            delegate?.accessDenied()
          }
        }
      }
    }
  }
}
