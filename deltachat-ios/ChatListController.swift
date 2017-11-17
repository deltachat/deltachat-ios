//
//  ChatListController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ChatListController: UIViewController {
    var chatList:MRChatList?

    let chatTable = UITableView()
    
    let chatTableDataSource = ChatTableDataSource()
    let chatTableDelegate = ChatTableDelegate()

    var msgChangedObserver: Any?
    var incomingMsgObserver: Any?
    
    func getChatList() {
        guard let chatlistPointer = mrmailbox_get_chatlist(mailboxPointer, 0, nil) else {
            fatalError("chatlistPointer was nil")
        }
        // ownership of chatlistPointer transferred here to ChatList object
        self.chatList = MRChatList(chatListPointer: chatlistPointer)
        
        chatTableDataSource.chatList = self.chatList
        chatTable.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        getChatList()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(forName:Notification.Name(rawValue:"MrEventMsgsChanged"),
                                            object:nil, queue:nil) {
                                                notification in
                                                print("----------- MrEventMsgsChanged notification received --------")
                                                self.getChatList()
        }
        
        incomingMsgObserver = nc.addObserver(forName:Notification.Name(rawValue:"MrEventIncomingMsg"),
                                             object:nil, queue:nil) {
                                                notification in
                                                print("----------- MrEventIncomingMsg received --------")
                                                self.getChatList()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let nc = NotificationCenter.default
        if let msgChangedObserver = self.msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let incomingMsgObserver = self.incomingMsgObserver {
            nc.removeObserver(incomingMsgObserver)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Delta Chat"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.addSubview(chatTable)
        chatTable.translatesAutoresizingMaskIntoConstraints = false
        chatTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        chatTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        chatTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        chatTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        chatTable.dataSource = chatTableDataSource
        chatTableDelegate.chatPresenter = self
        chatTable.delegate = chatTableDelegate
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(ChatListController.addChat))
        navigationItem.rightBarButtonItem = addButton
    }
    
    @objc func addChat() {
        let ncc = NewContactController()
        let nav = UINavigationController(rootViewController: ncc)
        present(nav, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ChatListController: ChatPresenter {
    func displayChat(index: Int) {
        guard let chatList = self.chatList else {
            fatalError("chatList was nil in ChatPresenter extension")
        }
        
        let chatId = chatList.getChatId(index: index)
        let chatVC = ChatViewController(chatId: chatId)

        chatVC.hidesBottomBarWhenPushed = true 
        self.navigationController?.pushViewController(chatVC, animated: true)
    }
}

class ChatTableDataSource: NSObject, UITableViewDataSource  {
    weak var chatList:MRChatList?
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let chatList = self.chatList else {
            fatalError("chatList was nil in data source")
        }
        print(chatList.length)
        
        return chatList.length
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        guard let chatList = self.chatList else {
            fatalError("chatList was nil in data source")
        }
        
        let cell:UITableViewCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") {
            cell = c
        } else {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ChatCell")
        }

        let chatId = chatList.getChatId(index: row)
        let chat = MRChat(id: chatId)
        let summary = chatList.summary(index: row)
        
        cell.textLabel?.text = "\(chat.name)"
        let result1 = summary.text1 ?? ""
        let result2 = summary.text2 ?? ""
        let result:String
        if !result1.isEmpty && !result2.isEmpty {
            result = "\(result1): \(result2)"
        } else {
            result = "\(result1)\(result2)"
        }
        
        cell.detailTextLabel?.text = result
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
