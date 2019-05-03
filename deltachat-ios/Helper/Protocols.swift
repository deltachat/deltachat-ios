//
//  Protocols.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 03.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

protocol Coordinator: class {
	var rootViewController: UIViewController { get }
}

protocol QrCodeReaderDelegate: class {
	func handleQrCode(_ code: String)
}

protocol ContactListDelegate: class {
	func accessGranted()
	func accessDenied()
	func deviceContactsImported()
}

protocol ChatDisplayer: class {
	func displayNewChat(contactId: Int)
	func displayChatForId(chatId: Int)
}
