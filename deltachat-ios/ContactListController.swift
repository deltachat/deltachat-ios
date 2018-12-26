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
        self.title = "Contacts"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contactIds.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell:ContactCell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseIdentifier, for: indexPath) as? ContactCell else {
            fatalError("shouldn't happen")
        }
        
        let row = indexPath.row
        let contactRow = row
        
        let contact = MRContact(id: contactIds[contactRow])
        cell.nameLabel.text = contact.name
        cell.emailLabel.text = contact.email
        
        if let img = contact.profileImage {
            cell.setImage(img)
        } else {
            cell.setBackupImage(name: contact.name, color: contact.color)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("view contact", indexPath.row)
        let contactId = contactIds[indexPath.row]
        let contactProfileController = ContactProfileViewController(contactId: contactId)
        navigationController?.pushViewController(contactProfileController, animated: true)
    }
}
