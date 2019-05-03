//
//  AppTabBarController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

/*
// TODO: delete
class AppTabBarController: UITabBarController {
  override func viewDidLoad() {
    super.viewDidLoad()

    let contactListController = ContactListController()
    let contactNavigationController = NavigationController(rootViewController: contactListController)
    let contactImage = UIImage(named: "contacts")
    contactNavigationController.tabBarItem = UITabBarItem(title: "Contacts", image: contactImage, tag: 0)

    let mailboxController = ChatViewController(chatId: Int(DC_CHAT_ID_DEADDROP), title: "Mailbox")
    mailboxController.disableWriting = true
    let mailboxNavigationController = NavigationController(rootViewController: mailboxController)
    let mailboxImage = UIImage(named: "message")
    mailboxNavigationController.tabBarItem = UITabBarItem(title: "Mailbox", image: mailboxImage, tag: 1)

    let profileController = ProfileViewController()
    let profileNavigationController = NavigationController(rootViewController: profileController)
    let profileImage = UIImage(named: "report_card")
    profileNavigationController.tabBarItem = UITabBarItem(title: "My Profile", image: profileImage, tag: 2)

    let chatListController = ChatListController()
    let chatNavigationController = NavigationController(rootViewController: chatListController)
    let chatImage = UIImage(named: "chat")
    chatNavigationController.tabBarItem = UITabBarItem(title: "Chats", image: chatImage, tag: 3)

    let settingsController = SettingsViewController()
    let settingsNavigationController = NavigationController(rootViewController: settingsController)
    let settingsImage = UIImage(named: "settings")
    settingsNavigationController.tabBarItem = UITabBarItem(title: "Settings", image: settingsImage, tag: 4)

    let tabBarList = [
      contactNavigationController,
      mailboxNavigationController,
      profileNavigationController,
      chatNavigationController,
      settingsNavigationController,
    ]

    viewControllers = tabBarList
    selectedIndex = 3

    tabBar.tintColor = DCColors.primary
  }
}
*/
