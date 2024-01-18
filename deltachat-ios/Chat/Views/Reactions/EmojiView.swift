import UIKit
import DcCore

class EmojiView: UIView {

    private let emojiLabel: UILabel

    init() {
        emojiLabel = UILabel()
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        super.init(frame: .zero)

        layer.borderWidth = 1
        layer.cornerRadius = 10
        layer.borderColor = DcColors.reactionBorder.cgColor

        addSubview(emojiLabel)
        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            emojiLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            emojiLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            trailingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 3),
            bottomAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 3),
        ]
        
        NSLayoutConstraint.activate(constraints)
    }

    func configure(with reaction: DcReaction) {
        if reaction.count == 1 {
            emojiLabel.text = reaction.emoji
        } else {
            emojiLabel.text = " \(reaction.emoji) \(reaction.count) "
        }

        if reaction.isFromSelf {
            backgroundColor = DcColors.messagePrimaryColor
            emojiLabel.textColor = DcColors.myReactionLabel
        } else {
            backgroundColor = DcColors.reactionBackground
            emojiLabel.textColor = DcColors.reactionLabel
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        layer.borderColor = DcColors.reactionBorder.cgColor
    }
}
