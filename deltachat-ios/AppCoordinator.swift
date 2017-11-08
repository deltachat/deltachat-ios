//
//  AppCoordinator.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

protocol Coordinator {
    func setupViewControllers(window: UIWindow)
}


class AppCoordinator: Coordinator {
    
    func setupViewControllers(window: UIWindow) {
        let contactViewController = ContactViewController(coordinator: self)
        contactViewController.view.backgroundColor = UIColor.red
        
        let chatViewController = ChatListController()
        let chatNavigationController = UINavigationController(rootViewController: chatViewController)
        
        chatViewController.view.backgroundColor = UIColor.green
        let settingsViewController = UIViewController()
        settingsViewController.view.backgroundColor = UIColor.blue
        
        
        
        let chatIcon = #imageLiteral(resourceName: "ic_chat_36pt").withRenderingMode(.alwaysTemplate)
        let contactsIcon = #imageLiteral(resourceName: "ic_people_36pt").withRenderingMode(.alwaysTemplate)
        let settingsIcon = #imageLiteral(resourceName: "ic_settings_36pt").withRenderingMode(.alwaysTemplate)
        
        let contactTabbarItem = UITabBarItem(title: "Contacts", image: contactsIcon, tag: 0)
        let chatTabbarItem = UITabBarItem(title: "Chats", image: chatIcon, tag: 1)
        let settingsTabbarItem = UITabBarItem(title: "Settings", image: settingsIcon, tag: 2)
        
        contactViewController.tabBarItem = contactTabbarItem
        chatNavigationController.tabBarItem = chatTabbarItem
        settingsViewController.tabBarItem = settingsTabbarItem
        
        let tabBarController = UITabBarController()
        
        tabBarController.viewControllers = [
            contactViewController,
            chatNavigationController,
            settingsViewController,
        ]
        
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        window.backgroundColor = UIColor.white
    }
    
}

