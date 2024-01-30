//
//  MessagePreviewViewController.swift
//  deltachat-ios
//
//  Created by Nathan Mattes on 29.01.24.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import UIKit
import DcCore

class MessagePreviewViewController: UIViewController {

    let scrollView: UIScrollView
    let contentStackView: UIStackView
    let reactionsView: SendReactionsView
    let messageBackgroundContainer: UIView
    let cellWrapper: UIView

    init(messageBackgroundContainer: UIView, messageId: String, myReactions: [DcReaction]) {

        self.messageBackgroundContainer = messageBackgroundContainer
        self.messageBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false

        cellWrapper = UIView()
        cellWrapper.translatesAutoresizingMaskIntoConstraints = false
        cellWrapper.addSubview(self.messageBackgroundContainer)
        cellWrapper.clipsToBounds = true
        cellWrapper.backgroundColor = .blue

        reactionsView = SendReactionsView(messageId: messageId, myReactions: myReactions)
        reactionsView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView = UIStackView(arrangedSubviews: [reactionsView, cellWrapper])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.spacing = 10
        contentStackView.axis = .vertical
        contentStackView.backgroundColor = .red

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStackView)
        scrollView.backgroundColor = .yellow

        super.init(nibName: nil, bundle: nil)

        view.addSubview(scrollView)

        setupConstraints()

    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),

            reactionsView.widthAnchor.constraint(equalTo: view.widthAnchor),
            cellWrapper.widthAnchor.constraint(equalTo: view.widthAnchor),
            cellWrapper.heightAnchor.constraint(equalToConstant: messageBackgroundContainer.frame.height),

            messageBackgroundContainer.topAnchor.constraint(equalTo: cellWrapper.topAnchor),
            messageBackgroundContainer.leadingAnchor.constraint(equalTo: cellWrapper.leadingAnchor),
            messageBackgroundContainer.trailingAnchor.constraint(equalTo: cellWrapper.trailingAnchor),
            messageBackgroundContainer.bottomAnchor.constraint(equalTo: cellWrapper.bottomAnchor),
        ]
        
        NSLayoutConstraint.activate(constraints)
    }
}
