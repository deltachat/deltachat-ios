import UIKit
import DcCore

class ChatTitleView: UIView {

    private var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        return titleLabel
    }()

    private var subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textAlignment = .center
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

        addConstraints([ containerView.constraintAlignTopTo(self),
                         containerView.constraintAlignBottomTo(self),
                         containerView.constraintCenterXTo(self),
                         containerView.constraintAlignLeadingTo(self),
                         containerView.constraintAlignTrailingTo(self)
        ])

        containerView.addSubview(titleLabel)
        containerView.addConstraints([ titleLabel.constraintAlignLeadingTo(containerView),
                                       titleLabel.constraintAlignTrailingTo(containerView),
                                       titleLabel.constraintAlignTopTo(containerView) ])

        containerView.addSubview(subtitleLabel)
        containerView.addConstraints([ subtitleLabel.constraintToBottomOf(titleLabel),
                                       subtitleLabel.constraintAlignLeadingTo(containerView),
                                       subtitleLabel.constraintAlignTrailingTo(containerView),
                                       subtitleLabel.constraintAlignBottomTo(containerView)])
    }

    func updateTitleView(title: String, subtitle: String?, baseColor: UIColor = DcColors.defaultTextColor) {
        subtitleLabel.textColor = baseColor.withAlphaComponent(0.95)
        titleLabel.textColor = baseColor
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
