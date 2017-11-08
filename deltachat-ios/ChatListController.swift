//
//  ChatListController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class Chat {
    
    private var chatPointer: UnsafeMutablePointer<mrchat_t>
    
    var id: Int {
        return Int(chatPointer.pointee.m_id)
    }
    
    var name: String {
        if chatPointer.pointee.m_name == nil {
            return "Error - no name"
        }
        return String(cString: chatPointer.pointee.m_name)
    }
    
    var type: Int {
        return Int(chatPointer.pointee.m_type)
    }
    
    init(id: Int) {
        chatPointer = mrmailbox_get_chat(mailboxPointer, UInt32(id))
    }
    
    deinit {
        mrchat_unref(chatPointer)
    }
}

class PoorText {
    
    private var poorTextPointer: UnsafeMutablePointer<mrpoortext_t>
    
    var text1: String? {
        if poorTextPointer.pointee.m_text1 == nil {
            return nil
        }
        return String(cString: poorTextPointer.pointee.m_text1)
    }
    
    var text2: String? {
        if poorTextPointer.pointee.m_text2 == nil {
            return nil
        }
        return String(cString: poorTextPointer.pointee.m_text2)
    }
    
    var text1Meaning: Int {
        return Int(poorTextPointer.pointee.m_text1_meaning)
    }
    
    var timeStamp: Int {
        return Int(poorTextPointer.pointee.m_timestamp)
    }
    
    var state: Int {
        return Int(poorTextPointer.pointee.m_state)
    }
    
    // takes ownership of specified pointer
    init(poorTextPointer: UnsafeMutablePointer<mrpoortext_t>) {
        self.poorTextPointer = poorTextPointer
    }
    
    deinit {
        mrpoortext_unref(poorTextPointer)
    }
}

class ChatList {
    
    private var chatListPointer: UnsafeMutablePointer<mrchatlist_t>
    
    var length: Int {
        return mrchatlist_get_cnt(chatListPointer)
        //return Int(chatListPointer.pointee.m_cnt)
    }
    
    // takes ownership of specified pointer
    init(chatListPointer: UnsafeMutablePointer<mrchatlist_t>) {
        self.chatListPointer = chatListPointer
    }

    func getChatId(index: Int) -> Int {
        return Int(mrchatlist_get_chat_id_by_index(self.chatListPointer, index))
    }
    
    func getMessageId(index: Int) -> Int {
        return Int(mrchatlist_get_msg_id_by_index(self.chatListPointer, index))
    }
    
    func summary(index: Int) -> PoorText {
        guard let poorTextPointer = mrchatlist_get_summary_by_index(self.chatListPointer, index, nil) else {
            fatalError("poor text pointer was nil")
        }
        return PoorText(poorTextPointer: poorTextPointer)
    }
    
    deinit {
        mrchatlist_unref(chatListPointer)
    }
}


class ChatListController: UIViewController {
    var chatList:ChatList?

    let chatTable = UITableView()
    
    let chatTableDataSource = ChatTableDataSource()
    let chatTableDelegate = ChatTableDelegate()
    
    override func viewWillAppear(_ animated: Bool) {
        guard let chatlistPointer = mrmailbox_get_chatlist(mailboxPointer, 0, nil) else {
            fatalError("chatlistPointer was nil")
        }
        // ownership of chatlistPointer transferred here to ChatList object
        self.chatList = ChatList(chatListPointer: chatlistPointer)
        
        chatTableDataSource.chatList = self.chatList
        chatTable.reloadData()
        
        /*
        let c_contacts = mrmailbox_get_known_contacts(mailboxPointer, nil)
        self.contactIds = Utils.copyAndFreeArray(inputArray: c_contacts)
        contactTableDataSource.contacts = self.contactIds
        contactTable.reloadData()
 */
    }
    
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
        chatTable.dataSource = chatTableDataSource
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
    weak var chatList:ChatList?
    
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
        let chat = Chat(id: chatId)
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

