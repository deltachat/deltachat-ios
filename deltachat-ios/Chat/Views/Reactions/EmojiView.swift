//
//  EmojiView.swift
//  deltachat-ios
//
//  Created by Nathan Mattes on 10.01.24.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import UIKit
import DcCore

class EmojiView: UIView {

    private let emojiLabel: UILabel

    init() {
        emojiLabel = UILabel()
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: .zero)

        layer.borderWidth = 2
        if #available(iOS 13.0, *) {
            layer.borderColor = UIColor.label.cgColor
        } else {
            layer.borderColor = UIColor.black.cgColor
        }
        layer.cornerRadius = 10

        addSubview(emojiLabel)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            emojiLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            emojiLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            trailingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 2),
            bottomAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 2),
        ]
        
        NSLayoutConstraint.activate(constraints)
    }

    func configure(with reaction: DcReaction) {
        if reaction.count == 1 {
            emojiLabel.text = reaction.emoji
        } else {
            emojiLabel.text = " \(reaction.count) \(reaction.emoji) "
        }

        if reaction.isFromSelf {
            layer.backgroundColor = UIColor.gray.cgColor
        } else {
            layer.backgroundColor = UIColor.white.cgColor
        }
    }

}
