//
//  ChatListController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ChatListController: UIViewController {
  var chatList: MRChatList?

  let chatTable = UITableView()

  let chatTableDataSource = ChatTableDataSource()
  let chatTableDelegate = ChatTableDelegate()

  var msgChangedObserver: Any?
  var incomingMsgObserver: Any?
  var viewChatObserver: Any?

  var newButton: UIBarButtonItem!

  func getChatList() {
    guard let chatlistPointer = dc_get_chatlist(mailboxPointer, DC_GCL_NO_SPECIALS, nil, 0) else {
      fatalError("chatlistPointer was nil")
    }
    // ownership of chatlistPointer transferred here to ChatList object
    chatList = MRChatList(chatListPointer: chatlistPointer)

    chatTableDataSource.chatList = chatList
    chatTable.reloadData()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if #available(iOS 11.0, *) {
      navigationController?.navigationBar.prefersLargeTitles = true
    }

    getChatList()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if #available(iOS 11.0, *) {
      navigationController?.navigationBar.prefersLargeTitles = false
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    let nc = NotificationCenter.default
    msgChangedObserver = nc.addObserver(forName: dcNotificationChanged,
                                        object: nil, queue: nil) {
      _ in
      self.getChatList()
    }

    incomingMsgObserver = nc.addObserver(forName: dcNotificationIncoming,
                                         object: nil, queue: nil) {
      _ in
      self.getChatList()
    }

    viewChatObserver = nc.addObserver(forName: dcNotificationViewChat, object: nil, queue: nil) {
      notification in
      if let chatId = notification.userInfo?["chat_id"] as? Int {
        self.displayChatForId(chatId: chatId)
      }
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    let nc = NotificationCenter.default
    if let msgChangedObserver = self.msgChangedObserver {
      nc.removeObserver(msgChangedObserver)
    }
    if let incomingMsgObserver = self.incomingMsgObserver {
      nc.removeObserver(incomingMsgObserver)
    }
    if let viewChatObserver = self.viewChatObserver {
      nc.removeObserver(viewChatObserver)
    }
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

    chatTable.rowHeight = 80

    let newImage = UIImage(named: "create_new")!
    newButton = UIBarButtonItem(image: newImage, landscapeImagePhone: nil, style: .plain, target: self, action: #selector(didPressNewChat))

    newButton.tintColor = Constants.primaryColor
    navigationItem.rightBarButtonItem = newButton
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
    navigationController?.pushViewController(chatVC, animated: true)
  }
}

extension ChatListController: ChatDisplayer {
  func displayNewChat(contactId: Int) {
    let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
    displayChatForId(chatId: Int(chatId))
  }

  func displayChatForId(chatId: Int) {
    let chatVC = ChatViewController(chatId: chatId)

    chatVC.hidesBottomBarWhenPushed = true
    navigationController?.pushViewController(chatVC, animated: true)
  }
}

class ChatTableDataSource: NSObject, UITableViewDataSource {
  weak var chatList: MRChatList?

  func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    guard let chatList = self.chatList else {
      fatalError("chatList was nil in data source")
    }

    return chatList.length
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = indexPath.row
    guard let chatList = self.chatList else {
      fatalError("chatList was nil in data source")
    }

    let cell: ContactCell
    if let c = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as? ContactCell {
      cell = c
    } else {
      cell = ContactCell(style: .default, reuseIdentifier: "ChatCell")
    }

    let chatId = chatList.getChatId(index: row)
    let chat = MRChat(id: chatId)
    let summary = chatList.summary(index: row)

    cell.nameLabel.text = chat.name
    if let img = chat.profileImage {
      cell.setImage(img)
    } else {
      cell.setBackupImage(name: chat.name, color: chat.color)
    }
    cell.setVerified(isVerified: chat.isVerified)

    let result1 = summary.text1 ?? ""
    let result2 = summary.text2 ?? ""
    let result: String
    if !result1.isEmpty, !result2.isEmpty {
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

  func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    let row = indexPath.row
    chatPresenter?.displayChat(index: row)
  }
}
