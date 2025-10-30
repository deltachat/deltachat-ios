import UIKit
import DcCore

class ChatTitleView: UIStackView {

    lazy var initialsBadge: InitialsBadge = {
        let badge: InitialsBadge
        badge = InitialsBadge(size: 37, accessibilityLabel: String.localized("menu_view_profile"))
        badge.accessibilityTraits = .button
        return badge
    }()

    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
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
        let stackView = UIStackView(arrangedSubviews: [titleLabel, muteView, ephemeralView, locationView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 3
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textAlignment = .center
        return subtitleLabel
    }()

    private lazy var textsContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleContainer, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    init() {
        super.init(frame: .zero)
        
        isAccessibilityElement = true
        axis = .horizontal
        alignment = .center
        spacing = 5
        addArrangedSubview(initialsBadge)
        addArrangedSubview(textsContainer)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitleView(title: String, subtitle: String?, isMuted: Bool, isEphemeral: Bool, isSendingLocations: Bool) {
        titleLabel.text = title
        titleLabel.textColor = DcColors.defaultTextColor
        muteView.isHidden = !isMuted
        ephemeralView.isHidden = !isEphemeral
        locationView.isHidden = !isSendingLocations

        if let subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.textColor = DcColors.defaultTextColor.withAlphaComponent(0.95)
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
    }

    func setEnabled(_ enabled: Bool) {
        titleLabel.isEnabled = enabled
        subtitleLabel.isEnabled = enabled
        muteView.alpha = enabled ? 1 : 0.4
        ephemeralView.alpha = enabled ? 1 : 0.4
        locationView.alpha = enabled ? 1 : 0.4
        initialsBadge.alpha = enabled ? 1 : 0.4
    }
}
