//
//  MailbovViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class MailboxViewController: ChatViewController {

	override init(chatId: Int, title: String? = nil) {
		super.init(chatId: chatId, title: title)
		hidesBottomBarWhenPushed = false
	}

	required init?(coder _: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		// Do any additional setup after loading the view.
	}


	/*
	// MARK: - Navigation

	// In a storyboard-based application, you will often want to do a little preparation before navigation
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
	// Get the new view controller using segue.destination.
	// Pass the selected object to the new view controller.
	}
	*/

}
