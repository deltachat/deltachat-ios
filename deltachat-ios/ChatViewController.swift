//
//  ChatViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ChatViewController: UIViewController {

    let chatTable = UITableView()
    
    let chatSource = ChatTableDataSource()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chats"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.addSubview(chatTable)
        chatTable.translatesAutoresizingMaskIntoConstraints = false
        chatTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        chatTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        chatTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        chatTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        chatTable.register(UITableViewCell.self , forCellReuseIdentifier: "ChatCell")
        chatTable.dataSource = chatSource
        chatTable.reloadData()
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

class ChatTableDataSource: NSObject, UITableViewDataSource  {
    
    var chats: [String] = ["Eins", "Zwei", "Drei"]
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell", for: indexPath)
        let title = chats[indexPath.row]
        cell.textLabel?.text = title
        return cell
    }
}

