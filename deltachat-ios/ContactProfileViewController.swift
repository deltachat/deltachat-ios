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
    let contactColor:UIColor
    var name:String {
        return MRContact(id: contactId).name
    }
    var email:String {
        return MRContact(id: contactId).email
    }
    
    init(contactId: Int, contactColor: UIColor) {
        self.contactId = contactId
        self.contactColor = contactColor
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.navigationBar.prefersLargeTitles = false
        tableView.reloadData()
    }
    
    func displayNewChat(contactId: Int) {
        let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
        let chatVC = ChatViewController(chatId: Int(chatId))
        
        chatVC.hidesBottomBarWhenPushed = true
        self.navigationController?.pushViewController(chatVC, animated: true)
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
            contactCell.setColor(self.contactColor)
            contactCell.darkMode = true
            contactCell.selectionStyle = .none
            return contactCell
        }
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

        let settingsImage = #imageLiteral(resourceName: "baseline_settings_black_18pt").withRenderingMode(.alwaysTemplate)
        cell.imageView?.image = settingsImage
        cell.imageView?.tintColor = UIColor.clear

        if row == 1 {
            cell.textLabel?.text = "Settings"
            cell.imageView?.tintColor = UIColor.gray
        }
        if row == 2 {
            cell.textLabel?.text = "Edit name"
        }
        /*if row == 3 {
            cell.textLabel?.text = "Encryption"
        }*/
        if row == 3 {
            cell.textLabel?.text = "New chat"
        }
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        
        if row == 1 {
            let alert = UIAlertController(title: "Not implemented", message: "Settings are not implemented yet.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
        }
        if row == 2 {
            let newContactController = NewContactController(contactIdForUpdate: contactId)
            navigationController?.pushViewController(newContactController, animated: true)
        }
        if row == 3 {
            displayNewChat(contactId: contactId)
        }
    }
}
