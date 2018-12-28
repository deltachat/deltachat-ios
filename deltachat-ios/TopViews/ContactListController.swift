//
//  ContactListController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class ContactListController: UITableViewController {
    let contactCellReuseIdentifier = "xyz"
    var contactIds: [Int] = Utils.getContactIds()
    var contactIdsForGroup: Set<Int> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Contacts"
        navigationController?.navigationBar.prefersLargeTitles = true

        contactIds = Utils.getContactIds()

        tableView.rowHeight = 80
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return contactIds.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ContactCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as? ContactCell {
            cell = c
        } else {
            cell = ContactCell(style: .subtitle, reuseIdentifier: "ChatCell")
        }
        let row = indexPath.row
        let contactRow = row

        let contact = MRContact(id: contactIds[contactRow])
        cell.nameLabel.text = contact.name
        cell.emailLabel.text = contact.email

        // TODO: provider a nice selection
        cell.selectionStyle = .none

        if let img = contact.profileImage {
            cell.setImage(img)
        } else {
            cell.setBackupImage(name: contact.name, color: contact.color)
        }
        cell.setVerified(isVerified: contact.isVerified)
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contactId = contactIds[indexPath.row]
        let contactProfileController = ContactProfileViewController(contactId: contactId)
        navigationController?.pushViewController(contactProfileController, animated: true)
    }
}
