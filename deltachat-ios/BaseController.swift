//
//  BaseController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 12.09.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class ProgressViewContainer: UIView {
    
    let progressView = UIProgressView(progressViewStyle: .default)
    
    
    init() {
        super.init(frame: .zero)
        self.backgroundColor = .white
        
        progressView.progressTintColor = .red
        progressView.trackTintColor = .lightGray
        progressView.progress = 0.1
        
        self.addSubview(progressView)
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.topAnchor.constraint(equalTo: self.topAnchor, constant: 40).isActive = true
        progressView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10).isActive = true
        progressView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10).isActive = true
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}




class BaseController: UIViewController {
    let progressViewContainer = ProgressViewContainer()
    var progressChangedObserver: Any?

    override func loadView() {
        self.view = progressViewContainer
    }
    
    override func viewDidLoad() {

    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        let nc = NotificationCenter.default
        progressChangedObserver = nc.addObserver(forName:Notification.Name(rawValue:"ProgressUpdated"),
                                            object:nil, queue:nil) {
                                                notification in
                                                print("----------- ProgressUpdated notification received --------")
                                                self.progressViewContainer.progressView.progress = AppDelegate.progress
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let nc = NotificationCenter.default
        if let progressChangedObserver = self.progressChangedObserver {
            nc.removeObserver(progressChangedObserver)
        }
    }
}






