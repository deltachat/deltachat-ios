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
        // super.viewDidLoad()

        title = "New Chat"
        navigationController?.navigationBar.prefersLargeTitles = true

        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(NewChatViewController.cancelButtonPressed))

        navigationItem.rightBarButtonItem = cancelButton
    }

    override func viewDidAppear(_: Bool) {
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

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return contactIds.count + 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        if row == 0 {
            // new group row
            let cell: UITableViewCell
            if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
                cell = c
            } else {
                cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
            }
            cell.textLabel?.text = "New Group"
            cell.textLabel?.textColor = view.tintColor

            return cell
        }
        if row == 1 {
            // new contact row
            let cell: UITableViewCell
            if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
                cell = c
            } else {
                cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
            }
            cell.textLabel?.text = "New Contact"
            cell.textLabel?.textColor = view.tintColor

            return cell
        }

        let cell: ContactCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "contactCell") as? ContactCell {
            cell = c
        } else {
            cell = ContactCell(style: .default, reuseIdentifier: "contactCell")
        }

        let contactRow = row - 2

        let contact = MRContact(id: contactIds[contactRow])
        cell.nameLabel.text = contact.name
        cell.emailLabel.text = contact.email
        cell.initialsLabel.text = Utils.getInitials(inputName: contact.name)
        cell.setColor(contact.color)

        cell.accessoryType = .detailDisclosureButton
        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        if row == 0 {
            let newGroupController = NewGroupViewController()
            navigationController?.pushViewController(newGroupController, animated: true)
        }
        if row == 1 {
            let newContactController = NewContactController()
            navigationController?.pushViewController(newContactController, animated: true)
        }
        if row > 1 {
            let contactIndex = row - 2
            let contactId = contactIds[contactIndex]
            dismiss(animated: false) {
                self.chatDisplayer?.displayNewChat(contactId: contactId)
            }
        }
    }

    override func tableView(_: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let row = indexPath.row
        if row > 1 {
            let contactIndex = row - 2
            let contactId = contactIds[contactIndex]
            // let newContactController = NewContactController(contactIdForUpdate: contactId)
            // navigationController?.pushViewController(newContactController, animated: true)
            let contactProfileController = ContactProfileViewController(contactId: contactId)
            navigationController?.pushViewController(contactProfileController, animated: true)
        }
    }
}
