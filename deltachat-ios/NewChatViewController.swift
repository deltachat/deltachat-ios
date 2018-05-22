//
//  NewChatViewController.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 21.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

protocol ChatDisplayer: class {
    func displayNewChat(contactId: Int)
}

class NewChatViewController: UITableViewController {
    var contactIds: [Int] = Utils.getContactIds()
    weak var chatDisplayer: ChatDisplayer?

    override func viewDidLoad() {
        //super.viewDidLoad()

        title = "New Chat"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(NewChatViewController.cancelButtonPressed))
        
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    override func viewDidAppear(_ animated: Bool) {
        contactIds = Utils.getContactIds()
        tableView.reloadData()
    }
    
    @objc func cancelButtonPressed() {
        dismiss(animated: true, completion: nil)
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
        return self.contactIds.count + 2
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        if row == 0 {
            // new contact row
            let cell:UITableViewCell
            if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
                cell = c
            } else {
                cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
            }
            cell.textLabel?.text = "New Contact"
            cell.textLabel?.textColor = self.view.tintColor


            return cell
        }
        if row == 1 {
            // new group row
            let cell:UITableViewCell
            if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
                cell = c
            } else {
                cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
            }
            cell.textLabel?.text = "New Group"
            cell.textLabel?.textColor = self.view.tintColor
            
            return cell
        }
        
        let cell:ContactCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "contactCell") as? ContactCell {
            cell = c
        } else {
            // cell = UITableViewCell(style: .value1, reuseIdentifier: "contactCell")
            cell = ContactCell(style: .default, reuseIdentifier: "contactCell")
        }
        
        let contactRow = row - 2

        let contact = MRContact(id: contactIds[contactRow])
        cell.nameLabel.text = contact.name
        cell.emailLabel.text = contact.email
        cell.initialsLabel.text = Utils.getInitials(inputName: contact.name)
        let contactColor = Utils.contactColor(row: contactRow)
        cell.setColor(contactColor)
        
        cell.accessoryType = .detailDisclosureButton
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if row == 0 {
            let newContactController = NewContactController()
            navigationController?.pushViewController(newContactController, animated: true)
        }
        if row == 1 {
            let alertController = UIAlertController(title: "Not implemented", message: "Adding groups is not yet implemented.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
            alertController.addAction(okAction)
            present(alertController, animated: false, completion: nil)
            tableView.deselectRow(at: indexPath, animated: true)
        }
        if row > 1 {
            let contactIndex = row - 2
            let contactId = contactIds[contactIndex]
            dismiss(animated: false) {
                self.chatDisplayer?.displayNewChat(contactId: contactId)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let row = indexPath.row
        if row > 1 {
            let contactIndex = row - 2
            let contactId = contactIds[contactIndex]
            // let newContactController = NewContactController(contactIdForUpdate: contactId)
            // navigationController?.pushViewController(newContactController, animated: true)
            let contactColor = Utils.contactColor(row: contactIndex)
            let contactProfileController = ContactProfileViewController(contactId: contactId, contactColor: contactColor)
            navigationController?.pushViewController(contactProfileController, animated: true)
        }
    }


    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
