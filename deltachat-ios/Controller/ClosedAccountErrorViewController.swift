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

class ClosedAccountErrorView: UIView {
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
    
    
    public init () {
        super.init(frame: .infinite)
        
        addSubview(titleLabel)
        addSubview(errorDescription1)
        addSubview(errorDescription2)
        
        backgroundColor = DcColors.defaultBackgroundColor
    }
    
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ClosedAccountErrorViewController: UIViewController {
    private let dcAccounts: DcAccounts
    private let dcContext: DcContext
    
    private lazy var hasOtherAccounts: Bool = {
        return dcAccounts.getAll().count >= 2
    }()
    
    private lazy var closedAccountErrorView: ClosedAccountErrorView = {
        let view2 = ClosedAccountErrorView()
        view2.translatesAutoresizingMaskIntoConstraints = false
        return view2
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
    
    private func setupSubviews() {
        view.addSubview(closedAccountErrorView)
        view.addSubview(titleLabel)
    }
    
    
    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

}
