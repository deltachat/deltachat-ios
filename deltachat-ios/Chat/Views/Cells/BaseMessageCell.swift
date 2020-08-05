import UIKit
import DcCore
public class BaseMessageCell: UITableViewCell {

    static var defaultPadding: CGFloat = 12
    static var containerPadding: CGFloat = -6
    typealias BMC = BaseMessageCell

    lazy var avatarView: InitialsBadge = {
        let view = InitialsBadge(size: 28)
        view.setColor(UIColor.gray)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var topLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "title"
        label.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        return label
    }()

    lazy var mainContentView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .horizontal
        return view
    }()

    lazy var bottomContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [bottomLabel])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .horizontal
        return view
    }()

    lazy var bottomLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        return label
    }()

    private lazy var contentContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [topLabel, mainContentView, bottomContentView])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        return view
    }()

    private lazy var messageBackgroundContainer: BackgroundContainer = {
        let container = BackgroundContainer()
        container.image = UIImage(color: UIColor.blue)
        container.contentMode = .scaleToFill
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    func setupSubviews() {
        contentView.addSubview(avatarView)
        contentView.addSubview(messageBackgroundContainer)
        contentView.addSubview(contentContainer)

        contentView.addConstraints([
            avatarView.constraintAlignTopTo(contentView, paddingTop: BMC.defaultPadding),
            avatarView.constraintAlignLeadingTo(contentView),
            avatarView.constraintAlignBottomTo(contentView, paddingBottom: BMC.defaultPadding, priority: .defaultLow),
            contentContainer.constraintToTrailingOf(avatarView, paddingLeading: BMC.defaultPadding),
            contentContainer.constraintAlignTrailingTo(contentView, paddingTrailing: BMC.defaultPadding),
            contentContainer.constraintAlignTopTo(contentView, paddingTop: BMC.defaultPadding),
            contentContainer.constraintAlignBottomTo(contentView, paddingBottom: BMC.defaultPadding),
            messageBackgroundContainer.constraintAlignLeadingTo(contentContainer, paddingLeading: BMC.containerPadding),
            messageBackgroundContainer.constraintAlignTopTo(contentContainer, paddingTop: BMC.containerPadding),
            messageBackgroundContainer.constraintAlignBottomTo(contentContainer, paddingBottom: BMC.containerPadding),
            messageBackgroundContainer.constraintAlignTrailingTo(contentContainer, paddingTrailing: BMC.containerPadding)
        ])
    }


    // update classes inheriting BaseMessageCell first before calling super.update(...)
    func update(msg: DcMsg, messageStyle: UIRectCorner) {
        topLabel.text = msg.fromContact.displayName
        avatarView.setName(msg.fromContact.displayName)
        avatarView.setColor(msg.fromContact.color)
        messageBackgroundContainer.update(rectCorners: messageStyle, color: msg.isFromCurrentSender ? DcColors.messagePrimaryColor : DcColors.messageSecondaryColor)
    }

    override public func prepareForReuse() {
        textLabel?.text = nil
        textLabel?.attributedText = nil
        topLabel.text = nil
        avatarView.reset()
        messageBackgroundContainer.prepareForReuse()
    }
}
