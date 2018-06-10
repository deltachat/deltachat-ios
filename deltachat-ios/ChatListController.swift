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
        guard let chatlistPointer = mrmailbox_get_chatlist(mailboxPointer, 0, nil, 0) else {
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
        navigationController?.navigationBar.prefersLargeTitles = false
        view.addSubview(chatTable)
        chatTable.translatesAutoresizingMaskIntoConstraints = false
        chatTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        chatTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        chatTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        chatTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        chatTable.dataSource = chatTableDataSource
        chatTableDelegate.chatPresenter = self
        chatTable.delegate = chatTableDelegate
        let dotsImage:UIImage = #imageLiteral(resourceName: "ic_more_vert")
        let dotsButton = UIBarButtonItem(image: dotsImage, landscapeImagePhone: nil, style: .plain, target: self, action: #selector(didPressDotsButton))
    
        navigationItem.rightBarButtonItem = dotsButton
    }
    
    @objc func didPressDotsButton() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "New chat",
                                            style: .default,
                                            handler: {
                                                [unowned self]
                                                a in
                                                self.didPressNewChat()
        }))
        /* actionSheet.addAction(UIAlertAction(title: "New group",
                                            style: .default,
                                            handler: {a in print("New group")}))
actionSheet.addAction(UIAlertAction(title: "Scan QR code",
                                            style: .default,
                                            handler: {a in print("Scan QR code")}))
        actionSheet.addAction(UIAlertAction(title: "Show QR code",
                                            style: .default,
                                            handler: {a in print("Show QR code")}))
        actionSheet.addAction(UIAlertAction(title: "Contact requests",
                                            style: .default,
                                            handler: {a in print("Contact requests")}))
        actionSheet.addAction(UIAlertAction(title: "Settings",
                                            style: .default,
                                            handler: {a in print("Settings")}))*/
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: {a in print("Cancel")}))
        present(actionSheet, animated: true, completion: nil)
        
        
    }
    
    @objc func didPressNewChat() {
        let ncv = NewChatViewController()
        ncv.chatDisplayer = self
        let nav = UINavigationController(rootViewController: ncv)
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

extension ChatListController: ChatDisplayer {
    func displayNewChat(contactId: Int) {
        let chatId = mrmailbox_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
        let chatVC = ChatViewController(chatId: Int(chatId))
        
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
        
        let cell:ContactCell
        if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as? ContactCell {
            cell = c
        } else {
            cell = ContactCell(style: .subtitle, reuseIdentifier: "ChatCell")
        }

        let chatId = chatList.getChatId(index: row)
        let chat = MRChat(id: chatId)
        let summary = chatList.summary(index: row)
        
        cell.nameLabel.text = chat.name
        cell.initialsLabel.text = Utils.getInitials(inputName: chat.name)
        let contactColor = Utils.color(row: row, colors: Constants.chatColors)
        cell.setColor(contactColor)
        let result1 = summary.text1 ?? ""
        let result2 = summary.text2 ?? ""
        let result:String
        if !result1.isEmpty && !result2.isEmpty {
            result = "\(result1): \(result2)"
        } else {
            result = "\(result1)\(result2)"
        }
        
        cell.emailLabel.text = result
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
