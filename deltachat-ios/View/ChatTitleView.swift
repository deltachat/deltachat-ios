import UIKit
import DcCore

class ChatTitleView: UIStackView {

    private lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return titleLabel
    }()

    private lazy var verifiedView: UIImageView = {
        let imgView = UIImageView()
        let img = UIImage(named: "verified")?.scaleDownImage(toMax: 14.4)
        imgView.isHidden = true
        imgView.image = img
        imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imgView
    }()

    private lazy var muteView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = DcColors.middleGray
        imageView.image = UIImage(systemName: "speaker.slash.fill")?.withRenderingMode(.alwaysTemplate)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        return imageView
    }()

    private lazy var titleContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, verifiedView, muteView])
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

    init() {
        super.init(frame: .zero)
        
        isAccessibilityElement = true
        axis = .vertical
        alignment = .center
        addArrangedSubview(titleContainer)
        addArrangedSubview(subtitleLabel)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateTitleView(title: String, subtitle: String?, isVerified: Bool, isMuted: Bool) {
        titleLabel.text = title
        titleLabel.textColor = DcColors.defaultTextColor
        verifiedView.isHidden = !isVerified
        muteView.isHidden = !isMuted

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
        verifiedView.alpha = enabled ? 1 : 0.4
    }
}
