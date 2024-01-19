import UIKit
import DcCore

enum DefaultReactions: CaseIterable {
    case thumbsUp
    case thumbsDown
    case heart
    case haha

    var emoji: String {
        switch self {
        case .thumbsUp: return "👍"
        case .thumbsDown: return "👎"
        case .heart: return "❤️"
        case .haha: return "😀"
        }
    }
}

protocol SendReactionsViewDelegate: AnyObject {
    func reactionButtonTapped(_ view: SendReactionsView, reaction: DefaultReactions, messageId: String)
}

class SendReactionsView: UIView {
    weak var delegate: SendReactionsViewDelegate?
    
    private let messageId: String
    let myReactions: [DcReaction]

    private let contentStackView: UIStackView
    private let thumbsUpReactionButton: UIButton
    private let thumbsDownReactionButton: UIButton
    private let heartReactionButton: UIButton
    private let hahaReactionButton: UIButton

    init(messageId: String, myReactions: [DcReaction]) {
        self.messageId = messageId
        self.myReactions = myReactions

        thumbsUpReactionButton = UIButton()
        thumbsDownReactionButton = UIButton()
        heartReactionButton = UIButton()
        hahaReactionButton = UIButton()

        let myEmojis = myReactions.map { $0.emoji }

        [
            (button: thumbsUpReactionButton, reaction: DefaultReactions.thumbsUp),
            (button: thumbsDownReactionButton, reaction: DefaultReactions.thumbsDown),
            (button: heartReactionButton, reaction: DefaultReactions.heart),
            (button: hahaReactionButton, reaction: DefaultReactions.haha)
        ].forEach {
            if #available(iOS 13, *) {
                if myEmojis.contains($0.reaction.emoji) {
                    $0.button.backgroundColor = DcColors.messagePrimaryColor
                } else {
                    $0.button.backgroundColor = .systemBackground
                }
            } else {
                if myEmojis.contains($0.reaction.emoji) {
                    $0.button.backgroundColor = DcColors.messagePrimaryColor
                } else {
                    $0.button.backgroundColor = .white
                }
            }

            $0.button.layer.cornerRadius = 8
            $0.button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 16)
            $0.button.titleEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: -8)
        }

        contentStackView = UIStackView(arrangedSubviews: [thumbsUpReactionButton, thumbsDownReactionButton, heartReactionButton, hahaReactionButton])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .horizontal

        contentStackView.spacing = 12

        super.init(frame: .zero)

        addSubview(contentStackView)

        thumbsUpReactionButton.setTitle(DefaultReactions.thumbsUp.emoji, for: .normal)
        thumbsUpReactionButton.addTarget(self, action: #selector(SendReactionsView.thumbsUpReactionButtonsButtonPressed(_:)), for: .touchUpInside)
        thumbsDownReactionButton.setTitle(DefaultReactions.thumbsDown.emoji, for: .normal)
        thumbsDownReactionButton.addTarget(self, action: #selector(SendReactionsView.thumbsDownReactionButtonsButtonPressed(_:)), for: .touchUpInside)
        heartReactionButton.setTitle(DefaultReactions.heart.emoji, for: .normal)
        heartReactionButton.addTarget(self, action: #selector(SendReactionsView.heartReactionButtonsButtonPressed(_:)), for: .touchUpInside)
        hahaReactionButton.setTitle(DefaultReactions.haha.emoji, for: .normal)
        hahaReactionButton.addTarget(self, action: #selector(SendReactionsView.hahaReactionButtonsButtonPressed(_:)), for: .touchUpInside)

        setupCostraints()

        backgroundColor = .clear
        layer.cornerRadius = 15
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupCostraints() {
        let constraints = [
            contentStackView.topAnchor.constraint(equalTo: topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(greaterThanOrEqualTo: contentStackView.trailingAnchor),
            bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor)
        ]

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Actions

    @objc func thumbsUpReactionButtonsButtonPressed(_ sender: Any) {
        delegate?.reactionButtonTapped(self, reaction: .thumbsUp, messageId: messageId)
    }

    @objc func thumbsDownReactionButtonsButtonPressed(_ sender: Any) {
        delegate?.reactionButtonTapped(self, reaction: .thumbsDown, messageId: messageId)
    }

    @objc func heartReactionButtonsButtonPressed(_ sender: Any) {
        delegate?.reactionButtonTapped(self, reaction: .heart, messageId: messageId)
    }

    @objc func hahaReactionButtonsButtonPressed(_ sender: Any) {
        delegate?.reactionButtonTapped(self, reaction: .haha, messageId: messageId)
    }
}
