//
//  ChatListController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class ChatListController: UIViewController {
	weak var coordinator: ChatListCoordinator?
	var chatList: MRChatList?

	lazy var chatTable: UITableView = {
		let chatTable = UITableView()
		chatTable.dataSource = self
		chatTable.delegate = self
		chatTable.rowHeight = 80
		return chatTable
	}()

	var msgChangedObserver: Any?
	var incomingMsgObserver: Any?
	var viewChatObserver: Any?

	var newButton: UIBarButtonItem!

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if #available(iOS 11.0, *) {
			navigationController?.navigationBar.prefersLargeTitles = true
			navigationItem.largeTitleDisplayMode = .always
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
				self.coordinator?.showChat(chatId: chatId)
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

		newButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.compose, target: self, action: #selector(didPressNewChat))
		newButton.tintColor = DCColors.primary
		navigationItem.rightBarButtonItem = newButton

		setupChatTable()
	}

	private func setupChatTable() {
		view.addSubview(chatTable)
		chatTable.translatesAutoresizingMaskIntoConstraints = false
		chatTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
		chatTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		chatTable.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
		chatTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
	}

	@objc func didPressNewChat() {
		coordinator?.showNewChatController()
	}

	func getChatList() {
		guard let chatlistPointer = dc_get_chatlist(mailboxPointer, DC_GCL_NO_SPECIALS, nil, 0) else {
			fatalError("chatlistPointer was nil")
		}
		// ownership of chatlistPointer transferred here to ChatList object
		chatList = MRChatList(chatListPointer: chatlistPointer)
		chatTable.reloadData()
	}
}

extension ChatListController: UITableViewDataSource, UITableViewDelegate {
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
		cell.setTimeLabel(summary.timeStamp)
		cell.setDeliveryStatusIndicator(summary.state)

		return cell
	}

	func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
		let row = indexPath.row
		if let chatId = chatList?.getChatId(index: row) {
			coordinator?.showChat(chatId: chatId)
		}
	}


	func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		let section = indexPath.section
		let row = indexPath.row
		guard let chatList = chatList else {
			return nil
		}

		// assigning swipe by delete to chats
		let delete = UITableViewRowAction(style: .destructive, title: "Delete") { [unowned self] _, indexPath in
			let chatId = chatList.getChatId(index: row)
			dc_delete_chat(mailboxPointer, UInt32(chatId))
			self.getChatList()

		}
		delete.backgroundColor = UIColor.red
		return [delete]
	}
}
