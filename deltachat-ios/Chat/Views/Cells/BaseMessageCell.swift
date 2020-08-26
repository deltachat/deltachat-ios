import UIKit
import DcCore
public class BaseMessageCell: UITableViewCell {

    static var defaultPadding: CGFloat = 12
    static var containerPadding: CGFloat = -6
    typealias BMC = BaseMessageCell

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var leadingConstraintCurrentSender: NSLayoutConstraint?
    private var trailingConstraintCurrentSender: NSLayoutConstraint?

    private lazy var contentContainer: UIStackView = {
        let view = UIStackView(arrangedSubviews: [topLabel, mainContentView, bottomContentView])
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.alignment = .leading
        view.axis = .vertical
        view.spacing = 6
        return view
    }()

    lazy var avatarView: InitialsBadge = {
        let view = InitialsBadge(size: 28)
        view.setColor(UIColor.gray)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.isHidden = true
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
        view.axis = .vertical
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
        clipsToBounds = false
        backgroundColor = .none
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    func setupSubviews() {
        contentView.addSubview(messageBackgroundContainer)
        contentView.addSubview(contentContainer)
        contentView.addSubview(avatarView)

        contentView.addConstraints([
            avatarView.constraintAlignTopTo(contentView, paddingTop: BMC.defaultPadding, priority: .defaultLow),
            avatarView.constraintAlignLeadingTo(contentView, paddingLeading: 6),
            avatarView.constraintAlignBottomTo(contentView, paddingBottom: -6),
            contentContainer.constraintAlignTopTo(contentView, paddingTop: BMC.defaultPadding),
            contentContainer.constraintAlignBottomTo(contentView, paddingBottom: BMC.defaultPadding),
            messageBackgroundContainer.constraintAlignLeadingTo(contentContainer, paddingLeading: 2 * BMC.containerPadding),
            messageBackgroundContainer.constraintAlignTopTo(contentContainer, paddingTop: BMC.containerPadding),
            messageBackgroundContainer.constraintAlignBottomTo(contentContainer, paddingBottom: BMC.containerPadding),
            messageBackgroundContainer.constraintAlignTrailingTo(contentContainer, paddingTrailing: BMC.containerPadding)
        ])

        self.leadingConstraint = contentContainer.constraintToTrailingOf(avatarView)
        self.trailingConstraint = contentContainer.constraintAlignTrailingMaxTo(contentView, paddingTrailing: BMC.defaultPadding)
        self.leadingConstraintCurrentSender = contentContainer.constraintAlignLeadingMaxTo(contentView, paddingLeading: 36)
        self.trailingConstraintCurrentSender = contentContainer.constraintAlignTrailingTo(contentView, paddingTrailing: BMC.defaultPadding)
    }


    // update classes inheriting BaseMessageCell first before calling super.update(...)
    func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool) {
        topLabel.text = msg.fromContact.displayName

        if msg.isFromCurrentSender {
            self.leadingConstraintCurrentSender?.isActive = true
            self.trailingConstraintCurrentSender?.isActive = true
        } else {
            self.leadingConstraint?.isActive = true
            self.trailingConstraint?.isActive = true
        }

        if isAvatarVisible {
            avatarView.isHidden = false
            avatarView.setName(msg.fromContact.displayName)
            avatarView.setColor(msg.fromContact.color)
            if let profileImage = msg.fromContact.profileImage {
                avatarView.setImage(profileImage)
            }
        }
        messageBackgroundContainer.update(rectCorners: messageStyle,
                                          color: msg.isFromCurrentSender ? DcColors.messagePrimaryColor : DcColors.messageSecondaryColor)

        if !msg.isInfo {
            bottomLabel.attributedText = getFormattedBottomLine(message: msg)
        }
    }

    func getFormattedBottomLine(message: DcMsg) -> NSAttributedString {
        var timestampAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: DcColors.grayDateColor,
            .paragraphStyle: NSParagraphStyle()
        ]

        let text = NSMutableAttributedString()
        if message.fromContactId == Int(DC_CONTACT_ID_SELF) {
            if let style = NSMutableParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle {
                style.alignment = .right
                timestampAttributes[.paragraphStyle] = style
            }

            text.append(NSAttributedString(string: message.formattedSentDate(), attributes: timestampAttributes))

            if message.showPadlock() {
                attachPadlock(to: text)
            }

            attachSendingState(message.state, to: text)
            return text
        }

        text.append(NSAttributedString(string: message.formattedSentDate(), attributes: timestampAttributes))
        if message.showPadlock() {
            attachPadlock(to: text)
        }
        return text
    }

    private func attachPadlock(to text: NSMutableAttributedString) {
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = UIImage(named: "ic_lock")
        imageAttachment.image?.accessibilityIdentifier = String.localized("encrypted_message")
        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([NSAttributedString.Key.baselineOffset: -1], range: NSRange(location: 0, length: 1))
        text.append(NSAttributedString(string: " "))
        text.append(imageString)
    }

    private func attachSendingState(_ state: Int, to text: NSMutableAttributedString) {
        let imageAttachment = NSTextAttachment()
        var offset = -4


        switch Int32(state) {
        case DC_STATE_OUT_PENDING, DC_STATE_OUT_PREPARING:
            imageAttachment.image = #imageLiteral(resourceName: "ic_hourglass_empty_white_36pt").scaleDownImage(toMax: 16)?.maskWithColor(color: DcColors.grayDateColor)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_sending")
            offset = -2
        case DC_STATE_OUT_DELIVERED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_36pt").scaleDownImage(toMax: 18)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_delivered")
        case DC_STATE_OUT_MDN_RCVD:
            imageAttachment.image = #imageLiteral(resourceName: "ic_done_all_36pt").scaleDownImage(toMax: 18)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_read")
            text.append(NSAttributedString(string: " "))
        case DC_STATE_OUT_FAILED:
            imageAttachment.image = #imageLiteral(resourceName: "ic_error_36pt").scaleDownImage(toMax: 16)
            imageAttachment.image?.accessibilityIdentifier = String.localized("a11y_delivery_status_error")
            offset = -2
        default:
            imageAttachment.image = nil
        }

        let imageString = NSMutableAttributedString(attachment: imageAttachment)
        imageString.addAttributes([.baselineOffset: offset],
                                  range: NSRange(location: 0, length: 1))
        text.append(imageString)
    }

    override public func prepareForReuse() {
        textLabel?.text = nil
        textLabel?.attributedText = nil
        topLabel.text = nil
        topLabel.attributedText = nil
        avatarView.reset()
        avatarView.isHidden = true
        messageBackgroundContainer.prepareForReuse()
        bottomLabel.text = nil
        bottomLabel.attributedText = nil
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false
        leadingConstraintCurrentSender?.isActive = false
        trailingConstraintCurrentSender?.isActive = false
    }
}
