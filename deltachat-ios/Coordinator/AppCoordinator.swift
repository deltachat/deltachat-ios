//
//  AppCoordinator.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class AppCoordinator: NSObject, Coordinator, UITabBarControllerDelegate {

	private let window: UIWindow

	var rootViewController: UIViewController {
		return tabBarController
	}

	private var childCoordinators:[Coordinator] = []

	private lazy var tabBarController: UITabBarController = {
		let tabBarController = UITabBarController()
		tabBarController.viewControllers = [contactListController, mailboxController, profileController, chatListController, settingsController]
		// put viewControllers here
		tabBarController.delegate = self
		tabBarController.tabBar.tintColor = DCColors.primary
		// tabBarController.tabBar.isTranslucent = false
		return tabBarController
	}()

	// MARK: viewControllers

	private lazy var contactListController: UIViewController = {
		let controller = ContactListController()
		let nav = NavigationController(rootViewController: controller)
		let settingsImage = UIImage(named: "contacts")
		nav.tabBarItem = UITabBarItem(title: "Contacts", image: settingsImage, tag: 4)
		let coordinator = ContactListCoordinator(rootViewController: nav)
		self.childCoordinators.append(coordinator)
		controller.coordinator = coordinator
		return nav
	}()

	private lazy var mailboxController: UIViewController = {
		let controller = ChatViewController(chatId: Int(DC_CHAT_ID_DEADDROP), title: "Mailbox")
		controller.disableWriting = true
		let nav = NavigationController(rootViewController: controller)
		let settingsImage = UIImage(named: "message")
		nav.tabBarItem = UITabBarItem(title: "Mailbox", image: settingsImage, tag: 4)
		let coordinator = ChatViewCoordinator(navigationController: nav)
		self.childCoordinators.append(coordinator)
		controller.coordinator = coordinator
		return nav
	}()

	private lazy var profileController: UIViewController = {
		let controller = ProfileViewController()
		let nav = NavigationController(rootViewController: controller)
		let settingsImage = UIImage(named: "report_card")
		nav.tabBarItem = UITabBarItem(title: "My Profile", image: settingsImage, tag: 4)
		let coordinator = ProfileCoordinator(rootViewController: nav)
		self.childCoordinators.append(coordinator)
		controller.coordinator = coordinator
		return nav
	}()

	private lazy var chatListController: UIViewController = {
		let controller = ChatListController()
		let nav = NavigationController(rootViewController: controller)
		let settingsImage = UIImage(named: "chat")
		nav.tabBarItem = UITabBarItem(title: "Chats", image: settingsImage, tag: 4)
		let coordinator = ChatListCoordinator(navigationController: nav)
		self.childCoordinators.append(coordinator)
		controller.coordinator = coordinator
		return nav
	}()

	private lazy var settingsController: UIViewController = {
		let controller = SettingsViewController()
		let nav = NavigationController(rootViewController: controller)
		let settingsImage = UIImage(named: "settings")
		nav.tabBarItem = UITabBarItem(title: "Settings", image: settingsImage, tag: 4)
		let coordinator = SettingsCoordinator(navigationController: nav)
		self.childCoordinators.append(coordinator)
		controller.coordinator = coordinator
		return nav
	}()

	init(window: UIWindow) {
		self.window = window
		super.init()
		window.rootViewController = rootViewController
		window.makeKeyAndVisible()
	}

	public func start() {
		self.showTab(index: 3)
	}

	public func showTab(index: Int) {
		tabBarController.selectedIndex = index
	}

	public func presentLoginController() {
		let accountSetupController = AccountSetupController()
		let accountSetupNavigationController = UINavigationController(rootViewController: accountSetupController)
		rootViewController.present(accountSetupNavigationController, animated: false, completion: nil)
	}


}

class ContactListCoordinator: Coordinator {
	var rootViewController: UIViewController

	init(rootViewController: UIViewController) {
		self.rootViewController = rootViewController
	}
}

class ChatViewCoordinator: Coordinator {
	var rootViewController: UIViewController
	let navigationController: UINavigationController

	var childCoordinators:[Coordinator] = []

	init(navigationController: UINavigationController) {
		self.rootViewController = navigationController.viewControllers.first!
		self.navigationController = navigationController
	}

	func showChatDetail(chatId: Int) {
		print("showChatDetail")
	}
}

class ProfileCoordinator: Coordinator {
	var rootViewController: UIViewController

	init(rootViewController: UIViewController) {
		self.rootViewController = rootViewController
	}
}

class ChatListCoordinator: Coordinator {
	var rootViewController: UIViewController
	let navigationController: UINavigationController

	var childCoordinators:[Coordinator] = []

	init(navigationController: UINavigationController) {
		self.rootViewController = navigationController.viewControllers.first!
		self.navigationController = navigationController
	}

	func showNewChatController() {
		let newChatVC = NewChatViewController()
		let coordinator = NewChatCoordinator(navigationController: self.navigationController)
		childCoordinators.append(coordinator)
		newChatVC.coordinator = coordinator
		newChatVC.hidesBottomBarWhenPushed = true
		navigationController.pushViewController(newChatVC, animated: true)
	}

	func showChat(chatId: Int) {
		let chatVC = ChatViewController(chatId: chatId)
		let coordinator = ChatViewCoordinator(navigationController: navigationController)
		childCoordinators.append(coordinator)
		chatVC.coordinator = coordinator
		chatVC.hidesBottomBarWhenPushed = true
		navigationController.pushViewController(chatVC, animated: true)

	}
}

class SettingsCoordinator: Coordinator {
	var rootViewController: UIViewController
	let navigationController: UINavigationController

	init(navigationController: UINavigationController) {
		self.rootViewController = navigationController.viewControllers.first!
		self.navigationController = navigationController
	}

	func showAccountSetupController() {
		let accountSetupVC = AccountSetupController()
		accountSetupVC.hidesBottomBarWhenPushed = true

		navigationController.pushViewController(accountSetupVC, animated: true)
	}
}

class NewChatCoordinator: Coordinator {
	var rootViewController: UIViewController
	let navigationController: UINavigationController

	private var childCoordinators:[Coordinator] = []

	init(navigationController: UINavigationController) {
		self.rootViewController = navigationController.viewControllers.first!
		self.navigationController = navigationController
	}


	func showNewGroupController() {
		let newGroupController = NewGroupViewController()
		navigationController.pushViewController(newGroupController, animated: true)
	}

	func showQRCodeController() {
		let controller = QrCodeReaderController()
		// controller.delegate = self
		//present(controller, animated: true, completion: nil)

	}

	func showNewContactController() {
		let newContactController = NewContactController()
		navigationController.pushViewController(newContactController, animated: true)
	}

	func showNewChat(contactId: Int) {
		let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
		showChat(chatId: Int(chatId))
	}

	func showChat(chatId: Int) {
		let chatViewController = ChatViewController(chatId: chatId)
		let coordinator = ChatViewCoordinator(navigationController: navigationController)
		childCoordinators.append(coordinator)
		chatViewController.coordinator = coordinator
		self.navigationController.pushViewController(chatViewController, animated: true)
		navigationController.viewControllers.remove(at: 1)
	}
}


