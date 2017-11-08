//
//  ContactViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class Contact {
    private var contactPointer: UnsafeMutablePointer<mrcontact_t>

    var name: String {
        return String(cString: contactPointer.pointee.m_name)
    }
    
    var email: String {
        return String(cString: contactPointer.pointee.m_addr)
    }
    
    var id: Int {
        return Int(contactPointer.pointee.m_id)
    }
    
    init(id: Int) {
        contactPointer = mrmailbox_get_contact(mailboxPointer, UInt32(id))
    }
    
    deinit {
        mrcontact_unref(contactPointer)
    }
}

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
        let c_contacts = mrmailbox_get_known_contacts(mailboxPointer, nil)
        self.contactIds = Utils.copyAndFreeArray(inputArray: c_contacts)
        contactTableDataSource.contacts = self.contactIds
        contactTable.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        contactTable.register(UITableViewCell.self, forCellReuseIdentifier: String(describing: UITableViewCell.self))
        contactTable.dataSource = self.contactTableDataSource
        contactTable.delegate = self.contactTableDelegate
        
        view.addSubview(contactTable)
        contactTable.translatesAutoresizingMaskIntoConstraints = false
        contactTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        contactTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        contactTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contactTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
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
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: UITableViewCell.self), for: indexPath)
        let row = indexPath.row
        let id = contacts[row]
        let contact = Contact(id: id)
        
        cell.textLabel?.text = contact.name

        return cell
    }
}

class ContactTableDelegate: NSObject, UITableViewDelegate {
    
}
