import UIKit
import DcCore

class ReactionsView: UIControl {

    private let reactionsStackView: UIStackView

    init() {
        reactionsStackView = UIStackView()
        reactionsStackView.axis = .horizontal
        reactionsStackView.translatesAutoresizingMaskIntoConstraints = false
        reactionsStackView.spacing = 2
        reactionsStackView.isUserInteractionEnabled = false

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
        let moreThanFiveReactions = reactions.reactions.count > 5

        var subviews: [UIView]
        if moreThanFiveReactions {
            subviews = reactions.reactions.prefix(4).map { reaction in
                let emojiView = EmojiView()
                emojiView.configure(with: reaction)
                return emojiView
            }

            let ellipsisBubble = EmojiView()
            ellipsisBubble.configure(with: DcReaction(emoji: " … "))
            subviews.append(ellipsisBubble)
            
        } else {
            subviews = reactions.reactions.prefix(5).map { reaction in
                let emojiView = EmojiView()
                emojiView.configure(with: reaction)
                return emojiView
            }
        }

        reactionsStackView.replaceSubviews(with: subviews)
    }

    public func prepareForReuse() {
        reactionsStackView.replaceSubviews(with: [])
    }
}

extension UIStackView {
    public func replaceSubviews(with newSubviews: [UIView]) {
        arrangedSubviews.forEach { [weak self] in
            $0.removeFromSuperview()
            self?.removeArrangedSubview($0)
        }
        newSubviews.forEach { [weak self] in self?.addArrangedSubview($0) }
    }
}
