//
//  NewGroupViewController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 17.07.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class NewGroupViewController: UITableViewController {

    let contactCellReuseIdentifier = "xyz"
    var contactIds: [Int] = Utils.getContactIds()
    var contactIdsForGroup: Set<Int> = [] {
        didSet {
            let c = contactIdsForGroup.count
            self.navigationItem.prompt = "\(c) members and me"
        }
    }
    
    @objc func didPressGroupCreationNextButton() {
        navigationController?.pushViewController(GroupNameController(), animated: true)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "New Group"
        self.navigationItem.prompt = "0 members and me"
        tableView.register(ContactCell.self, forCellReuseIdentifier: contactCellReuseIdentifier)
        navigationController?.navigationBar.prefersLargeTitles = false
        let groupCreationNextButton = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(didPressGroupCreationNextButton))
        navigationItem.rightBarButtonItem = groupCreationNextButton
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
        cell.initialsLabel.text = Utils.getInitials(inputName: contact.name)
        let contactColor = Utils.contactColor(row: contactRow)
        cell.setColor(contactColor)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if let cell = tableView.cellForRow(at: indexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            let contactId = contactIds[row]
            if contactIdsForGroup.contains(contactId) {
                contactIdsForGroup.remove(contactId)
                cell.accessoryType = .none
            } else {
                contactIdsForGroup.insert(contactId)
                cell.accessoryType = .checkmark
            }
        }
            
    }
 

}
