//
//  ContactViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ContactViewController: UIViewController {
    var coordinator: Coordinator
    var contactIds: [Int] = []
    
    let contactTable = UITableView()
    let contactTableDataSource = ContactTableDataSource()
    let contactTableDelegate = ContactTableDelegate()
    
    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let c_contacts = mrmailbox_get_contacts(mailboxPointer, 0, nil)
        self.contactIds = Utils.copyAndFreeArray(inputArray: c_contacts)
        contactTableDataSource.contacts = self.contactIds
        contactTable.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Contacts"
        navigationController?.navigationBar.prefersLargeTitles = true

        contactTable.dataSource = self.contactTableDataSource
        contactTable.delegate = self.contactTableDelegate
        
        view.addSubview(contactTable)
        contactTable.translatesAutoresizingMaskIntoConstraints = false
        contactTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contactTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contactTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contactTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
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
}

protocol ContactPresenter: class {
    
    
}

class ContactTableDataSource: NSObject, UITableViewDataSource {
    var contacts: [Int] = []

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell
        if let c = tableView.dequeueReusableCell(withIdentifier: String(describing: UITableViewCell.self)) {
            cell = c
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: String(describing: UITableViewCell.self))
        }
        let row = indexPath.row
        let id = contacts[row]
        let contact = MRContact(id: id)

        cell.textLabel?.text = contact.name
        cell.detailTextLabel?.text = contact.email

        return cell
    }
}

class ContactTableDelegate: NSObject, UITableViewDelegate {
    
}
