import UIKit

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
    private let contentStackView: UIStackView
    private let thumbsUpReactionButton: UIButton
    private let thumbsDownReactionButton: UIButton
    private let heartReactionButton: UIButton
    private let hahaReactionButton: UIButton

    init(messageId: String) {
        self.messageId = messageId

        thumbsUpReactionButton = UIButton()
        thumbsDownReactionButton = UIButton()
        heartReactionButton = UIButton()
        hahaReactionButton = UIButton()

        [thumbsUpReactionButton, thumbsDownReactionButton, heartReactionButton, hahaReactionButton].forEach {
            if #available(iOS 13, *) {
                $0.backgroundColor = .systemBackground
            } else {
                $0.backgroundColor = .white
            }

            $0.layer.cornerRadius = 8
            $0.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 16)
            $0.titleEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: -8)
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
