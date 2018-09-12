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
        window.rootViewController = baseController
        window.makeKeyAndVisible()
        window.backgroundColor = UIColor.white
        
        let ud = UserDefaults.standard
        if ud.bool(forKey: Constants.Keys.deltachatUserProvidedCredentialsKey) {
            initCore(withCredentials: false)
            setupInnerViewControllers()
        } else {
//            let email = "alice@librechat.net"
//            let password = "foobar"
//            initCore(email: email, password: password)
            
            displayCredentialsController()
        }
    }
    
    func displayCredentialsController() {
        let credentialsController = CredentialsController()
        let credentialsNav = UINavigationController(rootViewController: credentialsController)
        
        baseController.present(credentialsNav, animated: false, completion: nil)
    }
    
    func setupInnerViewControllers() {

        let chatViewController = ChatListController()
        let chatNavigationController = UINavigationController(rootViewController: chatViewController)
        
        baseController.present(chatNavigationController, animated: false, completion: nil)
    }
}
