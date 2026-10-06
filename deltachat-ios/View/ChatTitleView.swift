import UIKit
import DcCore

class ChatTitleView: UIView {

    lazy var button: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layoutMargins = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 10)
        button.isAccessibilityElement = true
        if #available(iOS 26.0, *) {
            button.configuration = .glass()
        }
        return button
    }()

    lazy var initialsBadge: InitialsBadge = {
        let badge: InitialsBadge
        badge = InitialsBadge(size: 37, accessibilityLabel: String.localized("menu_view_profile"))
        badge.accessibilityTraits = .button
        return badge
    }()

    private lazy var chatTitleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return titleLabel
    }()

    private lazy var muteView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = DcColors.middleGray
        imageView.image = UIImage(systemName: "speaker.slash.fill")?.withRenderingMode(.alwaysTemplate)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return imageView
    }()

    private lazy var ephemeralView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = DcColors.middleGray
        imageView.image = UIImage(systemName: "stopwatch")?.withRenderingMode(.alwaysTemplate)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return imageView
    }()

    private lazy var locationView: UIImageView = {
        return LocationStreamingIndicator(height: 16)
    }()

    private lazy var titleContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [chatTitleLabel, muteView, ephemeralView, locationView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 3
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var chatSubtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        return subtitleLabel
    }()

    private lazy var textsContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleContainer, chatSubtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var contentStack: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [initialsBadge, textsContainer])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 5
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    init() {
        super.init(frame: .zero)
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        button.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: button.layoutMarginsGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: button.layoutMarginsGuide.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: button.layoutMarginsGuide.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: button.layoutMarginsGuide.bottomAnchor),
        ])
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = contentStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let margins = button.layoutMargins
        return CGSize(width: .infinity, height: size.height + margins.top + margins.bottom)
    }

    func updateTitleView(title: String, subtitle: String?, isMuted: Bool, isEphemeral: Bool, isSendingLocations: Bool) {
        chatTitleLabel.text = title
        chatTitleLabel.textColor = DcColors.defaultTextColor
        muteView.isHidden = !isMuted
        ephemeralView.isHidden = !isEphemeral
        locationView.isHidden = !isSendingLocations

        if let subtitle {
            chatSubtitleLabel.text = subtitle
            chatSubtitleLabel.textColor = DcColors.defaultTextColor.withAlphaComponent(0.95)
            chatSubtitleLabel.isHidden = false
        } else {
            chatSubtitleLabel.isHidden = true
        }

        button.accessibilityLabel = [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        invalidateIntrinsicContentSize()
    }

    func setEnabled(_ enabled: Bool) {
        button.isEnabled = enabled
        chatTitleLabel.isEnabled = enabled
        chatSubtitleLabel.isEnabled = enabled
        muteView.alpha = enabled ? 1 : 0.4
        ephemeralView.alpha = enabled ? 1 : 0.4
        locationView.alpha = enabled ? 1 : 0.4
        initialsBadge.alpha = enabled ? 1 : 0.4
    }
}
