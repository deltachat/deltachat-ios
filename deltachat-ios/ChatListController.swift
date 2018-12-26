//
//  ChatListController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit
import Differ

class ChatListController: UIViewController {
    fileprivate var lastChatIds: [Int] = []
    
    var chatList:MRChatList?

    let chatTable = UITableView()
    
    let chatTableDataSource = ChatTableDataSource()
    let chatTableDelegate = ChatTableDelegate()

    var msgChangedObserver: Any?
    var incomingMsgObserver: Any?
    
    var dotsButton: UIBarButtonItem!
    
    func getChatList() {
        guard let chatlistPointer = dc_get_chatlist(mailboxPointer, 0, nil, 0) else {
            fatalError("chatlistPointer was nil")
        }
        // ownership of chatlistPointer transferred here to ChatList object
        let chatList = MRChatList(chatListPointer: chatlistPointer)
        self.chatList = chatList
        
        chatTableDataSource.chatList = self.chatList

        chatTable.animateRowChanges(oldData: lastChatIds, newData: chatList.chatIds)
        lastChatIds = chatList.chatIds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        getChatList()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let nc = NotificationCenter.default
        msgChangedObserver = nc.addObserver(forName:dc_notificationChanged,
                                            object:nil, queue:nil) {
                                                notification in
                                                print("----------- MrEventMsgsChanged notification received --------")
                                                self.getChatList()
        }
        
        incomingMsgObserver = nc.addObserver(forName:dc_notificationIncoming,
                                             object:nil, queue:nil) {
                                                notification in
                                                print("----------- MrEventIncomingMsg received --------")
                                                self.getChatList()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
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
        dotsButton = UIBarButtonItem(image: dotsImage, landscapeImagePhone: nil, style: .plain, target: self, action: #selector(didPressDotsButton))
    
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
                                            handler: {a in print("Contact requests")}))*/
        actionSheet.addAction(UIAlertAction(title: "Settings",
                                            style: .default,
                                            handler: {a in
                                                AppDelegate.appCoordinator.displayCredentialsController(isCancellable: true)
                                                
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: {a in print("Cancel")}))
        
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.barButtonItem = dotsButton
        }
        
        present(actionSheet, animated: true, completion: nil)
        
        
    }
    
    @objc func didPressNewChat() {
        let ncv = NewChatViewController()
        ncv.chatDisplayer = self
        let nav = UINavigationController(rootViewController: ncv)
        present(nav, animated: true, completion: nil)
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
    
    func deleteChat(index: Int) {
        chatList?.removeChat(index: index)
    }
}

extension ChatListController: ChatDisplayer {
    func displayNewChat(contactId: Int) {
        let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
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

        let chatId = chatList.chatIds[row]
        let chat = MRChat(id: chatId)
        let summary = chatList.summary(index: row)
        cell.selectionStyle = .none
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
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}

protocol ChatPresenter: class {
    func displayChat(index: Int)
    func deleteChat(index: Int)
}

class ChatTableDelegate: NSObject, UITableViewDelegate {
    
    weak var chatPresenter: ChatPresenter?
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        chatPresenter?.displayChat(index: row)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .normal, title: "Delete") { (rowAction, indexPath) in
            self.chatPresenter?.deleteChat(index: indexPath.row)
        }
        deleteAction.backgroundColor = .red
        
        return [deleteAction]
    }
}
