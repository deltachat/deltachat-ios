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

        let chatListController = ChatListController()
        let chatNavigationController = NavigationController(rootViewController: chatListController)
        let chatImage = UIImage(named: "chat")
        chatNavigationController.tabBarItem = UITabBarItem.init(title: "Chats", image: chatImage, tag: 1)
        
        let settingsController = SettingsViewController()
        let settingsNavigationController = NavigationController(rootViewController: settingsController)
        let settingsImage = UIImage(named: "settings")
        settingsNavigationController.tabBarItem = UITabBarItem.init(title: "Settings", image: settingsImage, tag: 2)
        
        let tabBarList = [contactNavigationController, chatNavigationController, settingsNavigationController]
        
        viewControllers = tabBarList
        self.selectedIndex = 1
        
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
