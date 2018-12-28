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
        backgroundColor = .lightGray

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        label.textAlignment = .center
        label.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -50).isActive = true
        label.textColor = .darkGray
        label.text = "Configuring…"

        let activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)

        activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 50).isActive = true
        activityIndicator.startAnimating()

        progressView.progressTintColor = .darkGray
        progressView.trackTintColor = .white
        progressView.progress = 0.0

        addSubview(progressView)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
        progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).isActive = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class BaseController: UIViewController {
    let progressViewContainer = ProgressViewContainer()
    var progressChangedObserver: Any?

    override func loadView() {
        view = progressViewContainer
    }

    override func viewDidLoad() {}

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let nc = NotificationCenter.default
        progressChangedObserver = nc.addObserver(forName: Notification.Name(rawValue: "ProgressUpdated"),
                                                 object: nil, queue: nil) {
            _ in
            logger.info("----------- ProgressUpdated notification received --------")
            self.progressViewContainer.progressView.progress = AppDelegate.progress
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let nc = NotificationCenter.default
        if let progressChangedObserver = self.progressChangedObserver {
            nc.removeObserver(progressChangedObserver)
        }
    }
}
