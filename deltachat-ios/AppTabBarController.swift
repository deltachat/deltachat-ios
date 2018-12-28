//
//  AppTabBarController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class AppTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let contactListController = ContactListController()
        let contactNavigationController = NavigationController(rootViewController: contactListController)
        let contactImage = UIImage(named: "contacts")
        contactNavigationController.tabBarItem = UITabBarItem.init(title: "Contacts", image: contactImage, tag: 0)

        let mailboxController = ChatViewController(chatId: Int(DC_CHAT_ID_DEADDROP))
        mailboxController.disableWriting = true
        let mailboxNavigationController = NavigationController(rootViewController: mailboxController)
        let mailboxImage = UIImage(named: "message")
        mailboxNavigationController.tabBarItem = UITabBarItem.init(title: "Mailbox", image: mailboxImage, tag: 1)

        let cameraController = CameraViewController()
        let cameraNavigationController = NavigationController(rootViewController: cameraController)
        let cameraImage = UIImage(named: "camera")
        cameraNavigationController.tabBarItem = UITabBarItem.init(title: "Camera", image: cameraImage, tag: 2)

        let chatListController = ChatListController()
        let chatNavigationController = NavigationController(rootViewController: chatListController)
        let chatImage = UIImage(named: "chat")
        chatNavigationController.tabBarItem = UITabBarItem.init(title: "Chats", image: chatImage, tag: 3)

        let settingsController = SettingsViewController()
        let settingsNavigationController = NavigationController(rootViewController: settingsController)
        let settingsImage = UIImage(named: "settings")
        settingsNavigationController.tabBarItem = UITabBarItem.init(title: "Settings", image: settingsImage, tag: 4)

        let tabBarList = [
          contactNavigationController,
          mailboxNavigationController,
          cameraNavigationController,
          chatNavigationController,
          settingsNavigationController
        ]

        viewControllers = tabBarList
        self.selectedIndex = 3

        tabBar.tintColor = Constants.primaryColor
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
