//
//  NewChatViewController.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 21.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class NewChatViewController: UITableViewController {
    var contactIds: [Int] = Utils.getContactIds()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "New Chat"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(NewChatViewController.cancelButtonPressed))
        
        navigationItem.rightBarButtonItem = cancelButton
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
        
        let cell:UITableViewCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "contactCell") {
            cell = c
        } else {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "contactCell")
        }
        
        let contactRow = row - 2

        let contact = MRContact(id: contactIds[contactRow])
        cell.textLabel?.text = contact.name
        cell.detailTextLabel?.text = contact.email

        return cell
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
