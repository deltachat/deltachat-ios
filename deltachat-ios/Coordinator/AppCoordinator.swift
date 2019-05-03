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
		let controller = ChatListController()
		let nav = NavigationController(rootViewController: controller)
		let settingsImage = UIImage(named: "message")
		nav.tabBarItem = UITabBarItem(title: "Mailbox", image: settingsImage, tag: 4)
		let coordinator = ChatListCoordinator(rootViewController: nav)
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
		let coordinator = ChatListCoordinator(rootViewController: nav)
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

	init(rootViewController: UIViewController) {
		self.rootViewController = rootViewController
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

	init(rootViewController: UIViewController) {
		self.rootViewController = rootViewController
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
		navigationController.pushViewController(AccountSetupController(), animated: true)
	}
}


