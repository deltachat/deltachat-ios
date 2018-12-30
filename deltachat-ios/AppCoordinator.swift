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
    let baseController = BaseController()

    func setupViewControllers(window: UIWindow) {
        window.rootViewController = AppTabBarController()
        window.makeKeyAndVisible()
    }

    func setupInnerViewControllers() {
        let chatListController = ChatListController()
        let chatNavigationController = UINavigationController(rootViewController: chatListController)

        baseController.present(chatNavigationController, animated: false, completion: nil)
    }
}
