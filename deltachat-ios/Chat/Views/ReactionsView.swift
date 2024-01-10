//
//  ReactionsView.swift
//  deltachat-ios
//
//  Created by Nathan Mattes on 10.01.24.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import UIKit
import DcCore

class ReactionsView: UIControl {

    private let reactionsStackView: UIStackView

    init() {
        reactionsStackView = UIStackView()
        reactionsStackView.axis = .horizontal
        reactionsStackView.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: .zero)

        addSubview(reactionsStackView)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            reactionsStackView.topAnchor.constraint(equalTo: topAnchor),
            reactionsStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: reactionsStackView.trailingAnchor),
            bottomAnchor.constraint(equalTo: reactionsStackView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    public func configure(with reactions: DcReactions) {
        let emojis = reactions.reactions.map { $0.emoji }.prefix(5)
        // TODO: check for more than 5 emojis

        let subviews = emojis.map { emoji in
            // TODO: Replace with custom EmojiView with a border and stuff
            let label = UILabel()
            label.text = emoji
            return label
        }

        reactionsStackView.replaceSubviews(with: subviews)

    }
}

extension UIStackView {
    public func replaceSubviews(with newSubviews: [UIView]) {
        arrangedSubviews.forEach { [weak self] in self?.removeArrangedSubview($0) }
        newSubviews.forEach { [weak self] in self?.addArrangedSubview($0) }
    }
}
