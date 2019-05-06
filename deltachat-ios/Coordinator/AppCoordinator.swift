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

  private var childCoordinators: [Coordinator] = []

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
    let coordinator = ContactListCoordinator(navigationController: nav)
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
    let coordinator = MailboxCoordinator(navigationController: nav)
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
    showTab(index: 3)
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
  let navigationController: UINavigationController

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
	}

	func showContactDetail(contactId: Int) {
		let contactProfileController = ContactDetailViewController(contactId: contactId)
		navigationController.pushViewController(contactProfileController, animated: true)

	}
}

// since mailbox and chatView -tab both use ChatViewController we want to be able to assign different functionality via coordinators -> therefore we override unneeded functions such as showChatDetail -> maybe find better solution in longterm
class MailboxCoordinator: ChatViewCoordinator {
  override func showChatDetail(chatId _: Int) {
    // ignore for now
  }
}

class ProfileCoordinator: Coordinator {
  var rootViewController: UIViewController

  init(rootViewController: UIViewController) {
    self.rootViewController = rootViewController
  }
}

class ChatListCoordinator: Coordinator {
  let navigationController: UINavigationController

  var childCoordinators: [Coordinator] = []

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func showNewChatController() {
    let newChatVC = NewChatViewController()
    let coordinator = NewChatCoordinator(navigationController: navigationController)
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
  let navigationController: UINavigationController

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func showAccountSetupController() {
    let accountSetupVC = AccountSetupController()
    accountSetupVC.hidesBottomBarWhenPushed = true

    navigationController.pushViewController(accountSetupVC, animated: true)
  }
}

class NewChatCoordinator: Coordinator {
  let navigationController: UINavigationController

  private var childCoordinators: [Coordinator] = []

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func showNewGroupController() {
    let newGroupController = NewGroupViewController()
    let coordinator = NewGroupCoordinator(navigationController: navigationController)
    childCoordinators.append(coordinator)
    newGroupController.coordinator = coordinator
    navigationController.pushViewController(newGroupController, animated: true)
  }

  func showQRCodeController() {
    let controller = QrCodeReaderController()
    // controller.delegate = self
    // present(controller, animated: true, completion: nil)
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
    navigationController.pushViewController(chatViewController, animated: true)
    navigationController.viewControllers.remove(at: 1)
  }
}

class ChatDetailCoordinator: Coordinator {
  let navigationController: UINavigationController

  private var childCoordinators: [Coordinator] = []

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }
}

class ChatViewCoordinator: Coordinator {
  let navigationController: UINavigationController

  var childCoordinators: [Coordinator] = []

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func showChatDetail(chatId: Int) {
    let chatDetailViewController = ChatDetailViewController(chatId: chatId)
    let coordinator = ChatDetailCoordinator(navigationController: navigationController)
    childCoordinators.append(coordinator)
    chatDetailViewController.coordinator = coordinator
    navigationController.pushViewController(chatDetailViewController, animated: true)
  }
}

class NewGroupCoordinator: Coordinator {
  let navigationController: UINavigationController

  private var childCoordinators: [Coordinator] = []

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func showGroupNameController(contactIdsForGroup: Set<Int>) {
    let groupNameController = GroupNameController(contactIdsForGroup: contactIdsForGroup)
    let coordinator = GroupNameCoordinator(navigationController: navigationController)
    childCoordinators.append(coordinator)
    groupNameController.coordinator = coordinator
    navigationController.pushViewController(groupNameController, animated: true)
  }
}

class GroupNameCoordinator: Coordinator {
  let navigationController: UINavigationController

  private var childCoordinators: [Coordinator] = []

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func showGroupChat(chatId: Int) {
    let chatViewController = ChatViewController(chatId: chatId)
    let coordinator = ChatViewCoordinator(navigationController: navigationController)
    childCoordinators.append(coordinator)
    chatViewController.coordinator = coordinator
    navigationController.popToRootViewController(animated: false)
    navigationController.pushViewController(chatViewController, animated: true)
  }
}
