//
//  ProviderInfoCell.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 20.02.20.
//  Copyright © 2020 Jonas Reinsch. All rights reserved.
//

import UIKit

enum ProviderInfoStatus {
     case preparation
     case broken
     case ok
 }

class ProviderInfoCell: UITableViewCell {

    private var hintBackgroundView: UIView = {
        let view = UIView()
        return view
    }()

    private var hintLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    private var infoButton: UIButton = {
        let button = UIButton()
        button.setTitle("more_info_desktop".lowercased(), for: .normal)
        return button
    }()

    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {

        let margin: CGFloat = 20

        contentView.addSubview(hintBackgroundView)
        hintBackgroundView.addSubview(hintLabel)
        hintBackgroundView.addSubview(infoButton)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        hintBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin).isActive = true
        hintBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        hintBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        hintBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true

        hintLabel.leadingAnchor.constraint(equalTo: hintBackgroundView.leadingAnchor, constant: 5).isActive = true
        hintLabel.topAnchor.constraint(equalTo: hintBackgroundView.topAnchor, constant: 5).isActive = true
        hintLabel.trailingAnchor.constraint(equalTo: hintBackgroundView.trailingAnchor, constant: -5).isActive = true

        infoButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 10).isActive = true
        infoButton.leadingAnchor.constraint(equalTo: hintBackgroundView.leadingAnchor, constant: 5).isActive = true
        infoButton.bottomAnchor.constraint(equalTo: hintBackgroundView.bottomAnchor, constant: -5).isActive = true
    }

    func updateInfo(hint text: String?, hintType: ProviderInfoStatus?) {
        hintLabel.text = text
        switch hintType {
        case .preparation:
            hintBackgroundView.backgroundColor = SystemColor.yellow.uiColor
        case .broken:
            hintBackgroundView.backgroundColor = SystemColor.red.uiColor
        case .ok:
            hintBackgroundView.backgroundColor = .clear
        case .none:
            break
        }
    }
}
