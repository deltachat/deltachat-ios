//
//  ClosedAccountErrorViewController.swift
//  deltachat-ios
//
//  Created by bb on 05.07.22.
//  Copyright © 2022 Jonas Reinsch. All rights reserved.
//

import Foundation
import UIKit
import DcCore


class ClosedAccountErrorViewController: UIViewController {
    private let dcAccounts: DcAccounts
    private let dcContext: DcContext
    
    private lazy var hasOtherAccounts: Bool = {
        return dcAccounts.getAll().count >= 2
    }()
   
    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()
        super.init(nibName: nil, bundle: nil)
        title = "Closed Account Error"
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Error: Account is closed"
        label.textColor = .red
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var errorDescription1: UILabel = {
        let label = UILabel()
        label.text = "This should not happen, please report it to the developers"
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 2
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var errorDescription2: UILabel = {
        let label = UILabel()
        label.text = "Anyways: just kill and restart the app this should fix the error."
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 2
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var tryFixButton: UIButton = {
       let button = UIButton()
        button.setTitle("Experimental: Try Fixing it without restart", for: .normal)
        button.addTarget(self, action: #selector(tryFix), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = DcColors.primary
        return button
    }()
    
    @objc
    private func tryFix() {
//        dcAccounts.stopIo()
//        dcAccounts.closeDatabase()
//        dcAccounts.openDatabase()
        let accountIds = dcAccounts.getAll()
        for accountId in accountIds {
            let dcContext = dcAccounts.get(id: accountId)
            if !dcContext.isOpen() {
                do {
                    let secret = try KeychainManager.getAccountSecret(accountID: accountId)
                    if !dcContext.open(passphrase: secret) {
                        logger.error("Failed to open database for account \(accountId)")
                    }
                } catch KeychainError.unhandledError(let message, let status) {
                    logger.error("Keychain error. \(message). Error status: \(status)")
                } catch {
                    logger.error("\(error)")
                }
            }
        }
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.appCoordinator.initializeRootController()
        }
    }
    
    private func setupSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(errorDescription1)
        view.addSubview(errorDescription2)
        view.addSubview(tryFixButton)
        
        view.addConstraints([
            titleLabel.constraintAlignTopToAnchor(view.safeAreaLayoutGuide.topAnchor, paddingTop: 50),
            errorDescription1.constraintToBottomOf(titleLabel, paddingTop: 6),
            errorDescription2.constraintToBottomOf(errorDescription1, paddingTop: 7),
            titleLabel.constraintAlignLeadingTo(view),
            titleLabel.constraintAlignTrailingTo(view),
            errorDescription1.constraintAlignLeadingTo(view),
            errorDescription1.constraintAlignTrailingTo(view),
            errorDescription2.constraintAlignLeadingTo(view),
            errorDescription2.constraintAlignTrailingTo(view),
            tryFixButton.constraintToBottomOf(errorDescription2, paddingTop: 5),
            tryFixButton.constraintCenterXTo(view),
        ])
        

    }
    
    
    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

}
