//
//  AppCoordinator.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 07.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class AppCoordinator {
    
    func setupMainViewControllers(window: UIWindow) {
        let contactViewController = UIViewController()
        contactViewController.view.backgroundColor = UIColor.red
        let chatViewController = UIViewController()
        chatViewController.view.backgroundColor = UIColor.green
        let settingsViewController = UIViewController()
        settingsViewController.view.backgroundColor = UIColor.blue
        
        let contactTabbarItem = UITabBarItem(tabBarSystemItem: .contacts, tag: 0)
        let chatTabbarItem = UITabBarItem(title: "Chat", image: nil, tag: 1)
        let settingsTabbarItem = UITabBarItem(title: "Settings", image: nil, tag: 2)
        
        contactViewController.tabBarItem = contactTabbarItem
        chatViewController.tabBarItem = chatTabbarItem
        settingsViewController.tabBarItem = settingsTabbarItem
        
        let tabBarController = UITabBarController()
        
        tabBarController.viewControllers = [
            contactViewController,
            chatViewController,
            settingsViewController,
        ]
        
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        window.backgroundColor = UIColor.white
    }
    
}

