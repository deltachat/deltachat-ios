//
//  ContactViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ContactViewController: UITableViewController {
    var contactIds: [Int] = []
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        contactIds = Utils.getContactIds()
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Contacts"
        navigationController?.navigationBar.prefersLargeTitles = true

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(ContactViewController.addContact))
        navigationItem.rightBarButtonItem = addButton
    }
    
    @objc func addContact() {
        let ncc = NewContactController()
        let nav = UINavigationController(rootViewController: ncc)
        present(nav, animated: true, completion: nil)
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
        return contactIds.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell
        if let c = tableView.dequeueReusableCell(withIdentifier: String(describing: UITableViewCell.self)) {
            cell = c
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: String(describing: UITableViewCell.self))
        }
        
        let contact = MRContact(id: contactIds[indexPath.row])
        
        cell.textLabel?.text = contact.name
        cell.detailTextLabel?.text = contact.email
        
        return cell
    }
}
