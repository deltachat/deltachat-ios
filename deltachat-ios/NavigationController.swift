//
//  NavigationController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

final class NavigationController: UINavigationController {
    var stateChangedObserver: Any?
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return viewControllers.last?.preferredStatusBarStyle ?? .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.isTranslucent = false
        navigationBar.tintColor = .white
        
        navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
       
        if #available(iOS 11.0, *) {
            navigationBar.prefersLargeTitles = true
            navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            navigationBar.barTintColor = Constants.primaryColor
        } else {
            navigationBar.setBackgroundImage(UIImage(), for: .default)
        }
        view.backgroundColor = Constants.primaryColor
        self.setShadow(nil)
        
        let nc = NotificationCenter.default
        stateChangedObserver = nc.addObserver(
            forName: dc_notificationStateChanged,
            object: nil,
            queue: nil) {
                notification in
                if let state = notification.userInfo?["state"] {
                    self.setShadow(state as? String)
                }
        }
    }
    
    private func setShadow(_ state: String?) {
        switch state {
        case "offline":
            navigationBar.shadowImage = Constants.defaultShadow
        case "online":
            navigationBar.shadowImage = Constants.onlineShadow
        default:
            navigationBar.shadowImage = Constants.defaultShadow
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let nc = NotificationCenter.default
        if let stateChangedObserver = self.stateChangedObserver {
            nc.removeObserver(stateChangedObserver)
        }
    }
    
    func setAppearanceStyle(to style: UIStatusBarStyle) {
        self.setShadow(nil)
        
        if style == .default {
            navigationBar.tintColor = .white
            navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
            if #available(iOS 11.0, *) {
                navigationBar.prefersLargeTitles = true
                navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                navigationBar.barTintColor = Constants.primaryColor
            }
        } else if style == .lightContent {
            navigationBar.tintColor = UIColor(red: 0, green: 0.5, blue: 1, alpha: 1)
            navigationBar.titleTextAttributes = [.foregroundColor: UIColor.black]
            if #available(iOS 11.0, *) {
                navigationBar.prefersLargeTitles = true
                navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
                navigationBar.barTintColor = .white
            }
        }
    }
}
