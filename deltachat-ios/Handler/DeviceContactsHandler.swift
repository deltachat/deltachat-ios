import Contacts
import UIKit
import DcCore

class DeviceContactsHandler {
    private let store = CNContactStore()
    weak var contactListDelegate: ContactListDelegate?
    let dcContext: DcContext

    init(dcContext: DcContext) {
        self.dcContext = dcContext
    }

    private func makeContactString(contacts: [CNContact]) -> String {
        var contactString: String = ""
        for contact in contacts {
            var displayName: String = "\(contact.givenName) \(contact.familyName)"
            displayName = displayName.replacingOccurrences(of: "\r", with: "") // remove characters later used as field separator
            displayName = displayName.replacingOccurrences(of: "\n", with: "")

            // cnContact can have multiple email addresses -> create contact for each email address
            for emailAddress in contact.emailAddresses {
                var adr: String = emailAddress.value as String
                adr = adr.replacingOccurrences(of: "\r", with: "") // remove characters later used as field separator
                adr = adr.replacingOccurrences(of: "\n", with: "")

                contactString += "\(displayName)\n\(adr)\n"
            }
        }
        return contactString
    }

    private func addContactsToCore() {
        fetchContactsWithEmailFromDevice { contacts in
            DispatchQueue.main.async {
                let contactString = self.makeContactString(contacts: contacts)
                self.dcContext.addContacts(contactString: contactString)
                self.contactListDelegate?.deviceContactsImported()
            }
        }
    }

    private func fetchContactsWithEmailFromDevice(completionHandler: @escaping ([CNContact]) -> Void) {

        DispatchQueue.global(qos: .background).async {
            let keys = [CNContactFamilyNameKey, CNContactGivenNameKey, CNContactEmailAddressesKey]

            var fetchedContacts: [CNContact] = []
            var allContainers: [CNContainer] = []

            do {
                allContainers = try self.store.containers(matching: nil)
            } catch {
                return
            }

            for container in allContainers {
                let predicates = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
                let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
                request.mutableObjects = true
                request.unifyResults = true
                request.sortOrder = .userDefault
                request.predicate = predicates
                do {
                    try self.store.enumerateContacts(with: request) { contact, _ in
                        if !contact.emailAddresses.isEmpty {
                            fetchedContacts.append(contact)
                        } else {
                            print(contact)
                        }
                    }
                } catch {
                    print(error)
                }
            }
            return completionHandler(fetchedContacts)
        }
    }

    public func importDeviceContacts() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            addContactsToCore()
            contactListDelegate?.accessGranted()
        case .denied:
            contactListDelegate?.accessDenied()
        case .restricted, .notDetermined:
            store.requestAccess(for: .contacts) { [weak self] granted, _ in
                guard let self = self else { return }
                if granted {
                    DispatchQueue.main.async {
                        self.addContactsToCore()
                        self.contactListDelegate?.accessGranted()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.contactListDelegate?.accessDenied()
                    }
                }
            }
        @unknown default:
            assertionFailure("")
        }
    }
}
