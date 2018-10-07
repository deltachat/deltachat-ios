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
    
    func displayCredentialsController(message: String? = nil, isCancellable:Bool = false) {
        let credentialsController = CredentialsController(isCancellable: isCancellable)
        
        let credentialsNav = UINavigationController(rootViewController: credentialsController)
        
        if baseController.presentedViewController != nil {
            baseController.dismiss(animated: false, completion: nil)
        }
        
        baseController.present(credentialsNav, animated: false) {
            if let message = message {
                let alert = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Help / Provider Overview", style: UIAlertAction.Style.default, handler: {
                    _ in
                    let url = URL(string: "https://support.delta.chat/t/provider-overview/56/2")!
                    UIApplication.shared.open(url, options: [:])
                }))
                
                alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                credentialsNav.present(alert, animated: false, completion: nil)
                
            }
        }
    }
    
    func setupInnerViewControllers() {

        let chatListController = ChatListController()
        let chatNavigationController = UINavigationController(rootViewController: chatListController)
        
        baseController.present(chatNavigationController, animated: false, completion: nil)
    }
}
