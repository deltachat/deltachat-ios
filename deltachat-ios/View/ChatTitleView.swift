import UIKit

class ChatTitleView: UIView {

    private var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        return titleLabel
    }()

    private var subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textAlignment = .center
        return subtitleLabel
    }()

    private let locationStreamingIndicator: UIImageView = {
        let view = UIImageView()
        view.tintColor = DcColors.checkmarkGreen
        view.translatesAutoresizingMaskIntoConstraints = false
        view.constraintHeightTo(28).isActive = true
        view.constraintWidthTo(28).isActive = true
        view.image = #imageLiteral(resourceName: "ic_location").withRenderingMode(.alwaysTemplate)
        view.isHidden = true
        return view
    }()

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
                         containerView.constraintCenterXTo(self)])

        containerView.addSubview(titleLabel)
        containerView.addConstraints([ titleLabel.constraintAlignLeadingTo(containerView),
                                       titleLabel.constraintAlignTrailingTo(containerView),
                                       titleLabel.constraintAlignTopTo(containerView) ])

        containerView.addSubview(subtitleLabel)
        containerView.addConstraints([ subtitleLabel.constraintToBottomOf(titleLabel),
                                       subtitleLabel.constraintAlignLeadingTo(containerView),
                                       subtitleLabel.constraintAlignTrailingTo(containerView),
                                       subtitleLabel.constraintAlignBottomTo(containerView)])
        addSubview(locationStreamingIndicator)
        addConstraints([
                         locationStreamingIndicator.constraintCenterYTo(self),
                         locationStreamingIndicator.constraintAlignTrailingTo(self),
                         locationStreamingIndicator.constraintToTrailingOf(containerView)])
    }

    func updateTitleView(title: String, subtitle: String?, baseColor: UIColor = DcColors.defaultTextColor, isLocationStreaming: Bool) {
        subtitleLabel.textColor = baseColor.withAlphaComponent(0.95)
        titleLabel.textColor = baseColor
        titleLabel.text = title
        subtitleLabel.text = subtitle
        locationStreamingIndicator.isHidden = !isLocationStreaming
    }
}
