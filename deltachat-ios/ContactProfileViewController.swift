//
//  TableViewController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 22.05.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class ContactProfileViewController: UITableViewController {
    let contactId:Int
    var name:String {
        return MRContact(id: contactId).name
    }
    var email:String {
        return MRContact(id: contactId).email
    }
    
    init(contactId: Int) {
        self.contactId = contactId
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.navigationBar.prefersLargeTitles = false
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        if row == 0 {
            let contactCell = ContactCell()
            contactCell.nameLabel.text = name
            contactCell.emailLabel.text = email
            contactCell.initialsLabel.text = Utils.getInitials(inputName: name)
            return contactCell
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

        if row == 1 {
            cell.textLabel?.text = "Settings"
        }
        if row == 2 {
            cell.textLabel?.text = "Edit name"
        }
        if row == 3 {
            cell.textLabel?.text = "Encryption"
        }
        if row == 4 {
            cell.textLabel?.text = "New chat"
        }
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if row == 2 {
            let newContactController = NewContactController(contactIdForUpdate: contactId)
            navigationController?.pushViewController(newContactController, animated: true)
        }
    }
}
