//
//  ChatListController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ChatListController: UIViewController {

    let chatTable = UITableView()
    var chats: [(String, String)] = [("Coffee Meeting", "Let's go or what? I..."), ("Daniela", "Did you hear about what Dr. J. was suggesting..."), ("Alice", "Did you receive..."), ("Bob", "Knock..."), ("Eva", "🍏")]
    
    let chatSource = ChatTableDataSource()
    let chatTableDelegate = ChatTableDelegate()
    
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
        chatSource.chats = chats
        chatTable.dataSource = chatSource
        chatTableDelegate.chatPresenter = self
        chatTable.delegate = chatTableDelegate
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ChatListController: ChatPresenter {
    func displayChat(index: Int) {
        let chatVC = ChatViewController()
        chatVC.title = chats[index].0
        chatVC.hidesBottomBarWhenPushed = true 
        self.navigationController?.pushViewController(chatVC, animated: true)
    }
}

class ChatTableDataSource: NSObject, UITableViewDataSource  {
    
    var chats: [(String, String)] = []
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") {
            cell = c
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ChatCell")
        }
        let title = chats[indexPath.row].0
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = chats[indexPath.row].1
        return cell
    }
}

protocol ChatPresenter: class {
    func displayChat(index: Int)
}

class ChatTableDelegate: NSObject, UITableViewDelegate {
    
    weak var chatPresenter: ChatPresenter?
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        chatPresenter?.displayChat(index: row)
    }
    
}

