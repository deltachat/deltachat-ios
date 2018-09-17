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
        self.backgroundColor = .lightGray
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(label)
        label.textAlignment = .center
        label.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -50).isActive = true
        label.textColor = .darkGray
        label.text = "Configuring…"
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(activityIndicator)
        
        activityIndicator.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        activityIndicator.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 50).isActive = true
        activityIndicator.startAnimating()
        
        
        progressView.progressTintColor = .darkGray
        progressView.trackTintColor = .white
        progressView.progress = 0.0
        
        self.addSubview(progressView)
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
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






