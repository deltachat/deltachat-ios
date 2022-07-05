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
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
    private lazy var errorDescription1: UILabel = {
        let label = UILabel()
        label.text = "This should not happen, please report it to the developers"
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        return label
    }()
    
    private lazy var errorDescription2: UILabel = {
        let label = UILabel()
        label.text = "Anyways: just kill and restart the app this should fix the error."
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.numberOfLines = 1
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        return label
    }()
    
    
    private func setupSubviews() {
        view.addSubview(titleLabel)
        view.addSubview(errorDescription1)
        view.addSubview(errorDescription2)
        
        let qrDefaultWidth = view.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.75)
        qrDefaultWidth.priority = UILayoutPriority(500)
        qrDefaultWidth.isActive = true
        let qrMinWidth = view.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        qrMinWidth.priority = UILayoutPriority(999)
        qrMinWidth.isActive = true
        view.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 1.05).isActive = true
        view.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        view.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
    }
    
    
    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

}
