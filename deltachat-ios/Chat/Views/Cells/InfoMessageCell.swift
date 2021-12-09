import UIKit
import DcCore

class InfoMessageCell: UITableViewCell {

    private lazy var messageBackgroundContainer: BackgroundContainer = {
        let container = BackgroundContainer()
        container.image = UIImage(color: DcColors.systemMessageBackgroundColor)
        container.contentMode = .scaleToFill
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.font = UIFont.preferredFont(for: .subheadline, weight: .medium)
        label.textColor = DcColors.systemMessageFontColor
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        clipsToBounds = false
        backgroundColor = .clear
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupSubviews() {
        contentView.addSubview(messageBackgroundContainer)
        contentView.addSubview(messageLabel)

        contentView.addConstraints([
            messageLabel.constraintAlignTopTo(contentView, paddingTop: 12),
            messageLabel.constraintAlignBottomTo(contentView, paddingBottom: 12),
            messageLabel.constraintAlignLeadingMaxTo(contentView, paddingLeading: 50),
            messageLabel.constraintAlignTrailingMaxTo(contentView, paddingTrailing: 50),
            messageLabel.constraintCenterXTo(contentView),
            messageBackgroundContainer.constraintAlignLeadingTo(messageLabel, paddingLeading: -6),
            messageBackgroundContainer.constraintAlignTopTo(messageLabel, paddingTop: -6),
            messageBackgroundContainer.constraintAlignBottomTo(messageLabel, paddingBottom: -6),
            messageBackgroundContainer.constraintAlignTrailingTo(messageLabel, paddingTrailing: -6)
        ])
        selectionStyle = .none
    }

    func update(text: String?) {
        messageLabel.text = text
        var corners: UIRectCorner = []
        corners.formUnion(.topLeft)
        corners.formUnion(.bottomLeft)
        corners.formUnion(.topRight)
        corners.formUnion(.bottomRight)
        messageBackgroundContainer.update(rectCorners: corners, color: DcColors.systemMessageBackgroundColor)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        messageLabel.attributedText = nil
    }

}
