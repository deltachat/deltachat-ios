import UIKit
import DcCore

class InfoMessageCell: UITableViewCell {

    private var showSelectionBackground: Bool
    private var trailingConstraint: NSLayoutConstraint?
    private var trailingConstraintEditingMode: NSLayoutConstraint?

    // icon image height and width (square icon)
    public var imageSize: CGFloat {
        get {
            return imageHeightConstraint?.constant ?? 0
        }
        set {
            imageHeightConstraint?.constant = newValue
        }
    }

    private var imageHeightConstraint: NSLayoutConstraint?

    private lazy var iconView: UIImageView = {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFill
        return image
    }()

    private lazy var contentContainerView: UIStackView = {
        let container = UIStackView(arrangedSubviews: [iconView, messageLabel])
        container.axis = .horizontal
        container.distribution = .fill
        container.spacing = 6
        container.alignment = .center
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

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
        label.textColor = DcColors.systemMessageFontColor
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.showSelectionBackground = false
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
        contentView.addSubview(contentContainerView)
        contentView.addConstraints([
            contentContainerView.constraintAlignTopTo(contentView, paddingTop: 12, priority: .defaultLow),
            contentContainerView.constraintAlignBottomTo(contentView, paddingBottom: 12, priority: .defaultLow),
            contentContainerView.constraintAlignLeadingMaxTo(contentView, paddingLeading: 55),
            contentContainerView.constraintCenterXTo(contentView, priority: .defaultLow),
            messageBackgroundContainer.constraintAlignLeadingTo(contentContainerView, paddingLeading: -10),
            messageBackgroundContainer.constraintAlignTopTo(contentContainerView, paddingTop: -6),
            messageBackgroundContainer.constraintAlignBottomTo(contentContainerView, paddingBottom: -6),
            messageBackgroundContainer.constraintAlignTrailingTo(contentContainerView, paddingTrailing: -10),
            iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor),
        ])

        imageHeightConstraint = iconView.constraintHeightTo(0, priority: .required)
        imageSize = UIFont.preferredFont(for: .subheadline, weight: .medium).pointSize
        imageHeightConstraint?.isActive = true
        trailingConstraint = messageLabel.constraintAlignTrailingMaxTo(contentView, paddingTrailing: 55)
        trailingConstraintEditingMode = messageLabel.constraintAlignTrailingMaxTo(contentView, paddingTrailing: 10)
        trailingConstraint?.isActive = !isEditing
        trailingConstraintEditingMode?.isActive = isEditing
    }

    func update(text: String?, weight: UIFont.Weight? = nil, image: UIImage? = nil) {
        messageLabel.text = text
        if let weight = weight {
            messageLabel.font = UIFont.preferredFont(for: .subheadline, weight: weight)
        } else {
            messageLabel.font =  UIFont.preferredFont(for: .subheadline, weight: .medium)
        }
        iconView.image = image
        iconView.isHidden = image == nil
        var corners: UIRectCorner = []
        corners.formUnion(.topLeft)
        corners.formUnion(.bottomLeft)
        corners.formUnion(.topRight)
        corners.formUnion(.bottomRight)
        messageBackgroundContainer.update(rectCorners: corners, color: DcColors.systemMessageBackgroundColor)
        trailingConstraint?.isActive = !isEditing
        trailingConstraintEditingMode?.isActive = isEditing
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory &&
            !iconView.isHidden {
            imageSize = UIFont.preferredFont(for: .subheadline, weight: .medium).pointSize
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        messageLabel.attributedText = nil
        showSelectionBackground = false
        iconView.image = nil
    }
    
    public override func willTransition(to state: UITableViewCell.StateMask) {
        super.willTransition(to: state)
        // while the content view gets intended by the appearance of the edit control,
        // we're adapting the the padding of the messages on the left side of the screen
        if state == .showingEditControl {
            if trailingConstraint?.isActive ?? false {
                trailingConstraint?.isActive = false
                trailingConstraintEditingMode?.isActive = true
            }
        } else {
            if trailingConstraintEditingMode?.isActive ?? false {
                trailingConstraintEditingMode?.isActive = false
                trailingConstraint?.isActive = true
            }
        }
    }

    public override func setSelected(_ selected: Bool, animated: Bool) {
         super.setSelected(selected, animated: animated)
         if selected && showSelectionBackground {
             selectedBackgroundView?.backgroundColor = DcColors.chatBackgroundColor.withAlphaComponent(0.5)
         } else {
             selectedBackgroundView?.backgroundColor = .clear
         }
     }
}

extension InfoMessageCell: SelectableCell {
    public func showSelectionBackground(_ show: Bool) {
        selectionStyle = show ? .default : .none
        showSelectionBackground = show
    }
}
