import UIKit
import DcCore

class ChatTitleView: UIView {

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

    private lazy var titleContainer: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, verifiedView])
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
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        return subtitleLabel
    }()

    private let paddingNaviationButtons = 120
    private let sizeStreamingIndicator = 28

    init() {
        super.init(frame: .zero)
        setupSubviews()
        isAccessibilityElement = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        containerView.addSubview(titleContainer)
        containerView.addSubview(subtitleLabel)

        addConstraints([ containerView.constraintAlignTopTo(self),
                         containerView.constraintAlignBottomTo(self),
                         containerView.constraintCenterXTo(self),
                         containerView.constraintAlignLeadingTo(self),
                         containerView.constraintAlignTrailingTo(self),
                         titleContainer.constraintAlignLeadingTo(containerView),
                         titleContainer.constraintAlignTrailingTo(containerView),
                         titleContainer.constraintAlignTopTo(containerView),
                         subtitleLabel.constraintToBottomOf(titleContainer),
                         subtitleLabel.constraintAlignLeadingTo(containerView),
                         subtitleLabel.constraintAlignTrailingTo(containerView),
                         subtitleLabel.constraintAlignBottomTo(containerView),
                         verifiedView.widthAnchor.constraint(equalTo: verifiedView.heightAnchor)
        ])
    }

    func updateTitleView(title: String, subtitle: String?, baseColor: UIColor = DcColors.defaultTextColor, isVerified: Bool) {
        subtitleLabel.textColor = baseColor.withAlphaComponent(0.95)
        titleLabel.textColor = baseColor
        titleLabel.text = title
        subtitleLabel.text = subtitle
        verifiedView.isHidden = !isVerified
    }
}
