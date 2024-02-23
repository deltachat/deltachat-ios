import Foundation
import UIKit
import DcCore

public class VideoInviteCell: UITableViewCell {

    private lazy var messageBackgroundContainer: BackgroundContainer = {
        let container = BackgroundContainer()
        container.image = UIImage(color: DcColors.systemMessageBackgroundColor)
        container.contentMode = .scaleToFill
        container.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }()

    lazy var avatarView: InitialsBadge = {
        let view = InitialsBadge(size: 28)
        view.setColor(DcColors.systemMessageBackgroundColor)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return view
    }()

    lazy var videoIcon: InitialsBadge = {
        let view = InitialsBadge(size: 28)
        view.setColor(DcColors.systemMessageBackgroundColor)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.setImage(#imageLiteral(resourceName: "ic_videochat").withRenderingMode(.alwaysTemplate))
        view.tintColor = .white
        view.imagePadding = 3
        return view
    }()

    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.font = UIFont.preferredFont(for: .body, weight: .regular)
        label.textColor = DcColors.systemMessageFontColor
        return label
    }()

    lazy var openLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.font = UIFont.preferredFont(for: .body, weight: .bold)
        label.textColor = DcColors.systemMessageFontColor
        return label
    }()

    lazy var bottomLabel: StatusView = {
        let statusView = StatusView()
        statusView.translatesAutoresizingMaskIntoConstraints = false
        return statusView
    }()
    
    private var showSelectionBackground: Bool


    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        showSelectionBackground = false
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        clipsToBounds = false
        backgroundColor = .clear
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupSubviews() {
        contentView.addSubview(videoIcon)
        contentView.addSubview(avatarView)
        contentView.addSubview(messageBackgroundContainer)
        contentView.addSubview(messageLabel)
        contentView.addSubview(openLabel)
        contentView.addSubview(bottomLabel)
        contentView.addConstraints([
            videoIcon.constraintAlignTopTo(contentView, paddingTop: 12),
            videoIcon.constraintCenterXTo(contentView, paddingX: -20),
            avatarView.constraintAlignTopTo(contentView, paddingTop: 12),
            avatarView.constraintCenterXTo(contentView, paddingX: 20),
            messageLabel.constraintToBottomOf(videoIcon, paddingTop: 16),
            messageLabel.constraintAlignLeadingMaxTo(contentView, paddingLeading: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 50),
            messageLabel.constraintAlignTrailingMaxTo(contentView, paddingTrailing: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 50),
            messageLabel.constraintCenterXTo(contentView),
            openLabel.constraintToBottomOf(messageLabel),
            openLabel.constraintCenterXTo(contentView),
            openLabel.constraintAlignLeadingMaxTo(contentView, paddingLeading: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 50),
            openLabel.constraintAlignTrailingMaxTo(contentView, paddingTrailing: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 50),
            messageBackgroundContainer.constraintAlignLeadingTo(messageLabel, paddingLeading: -6),
            messageBackgroundContainer.constraintAlignTopTo(messageLabel, paddingTop: -6),
            messageBackgroundContainer.constraintAlignBottomTo(openLabel, paddingBottom: -6),
            messageBackgroundContainer.constraintAlignTrailingTo(messageLabel, paddingTrailing: -6),
            bottomLabel.constraintAlignTrailingTo(messageBackgroundContainer),
            bottomLabel.constraintToBottomOf(messageBackgroundContainer, paddingTop: 8),
            bottomLabel.constraintAlignLeadingMaxTo(contentView, paddingLeading: UIDevice.current.userInterfaceIdiom == .pad ? 150 : 50),
            bottomLabel.constraintAlignBottomTo(contentView, paddingBottom: 12)
        ])
    }

    func update(dcContext: DcContext, msg: DcMsg) {
        let fromContact = dcContext.getContact(id: msg.fromContactId)
        if msg.isFromCurrentSender {
            messageLabel.text = String.localized("videochat_you_invited_hint")
            openLabel.text = String.localized("videochat_tap_to_open")

        } else {
            messageLabel.text = String.localizedStringWithFormat(String.localized("videochat_contact_invited_hint"), fromContact.displayName)
            openLabel.text = String.localized("videochat_tap_to_join")
        }
        avatarView.setName(msg.getSenderName(fromContact))
        avatarView.setColor(fromContact.color)
        if let profileImage = fromContact.profileImage {
            avatarView.setImage(profileImage)
        }

        bottomLabel.update(message: msg, tintColor: DcColors.coreDark05)

        var corners: UIRectCorner = []
        corners.formUnion(.topLeft)
        corners.formUnion(.bottomLeft)
        corners.formUnion(.topRight)
        corners.formUnion(.bottomRight)
        messageBackgroundContainer.update(rectCorners: corners, color: DcColors.systemMessageBackgroundColor)
    }

    public override func setSelected(_ selected: Bool, animated: Bool) {
         super.setSelected(selected, animated: animated)
         if selected && showSelectionBackground {
             selectedBackgroundView?.backgroundColor = DcColors.chatBackgroundColor.withAlphaComponent(0.5)
         } else {
             selectedBackgroundView?.backgroundColor = .clear
         }
     }

    public override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        messageLabel.attributedText = nil
        bottomLabel.prepareForReuse()
        openLabel.text = nil
        openLabel.attributedText = nil
        avatarView.reset()
        showSelectionBackground = false
    }
}

extension VideoInviteCell: SelectableCell {
    public func showSelectionBackground(_ show: Bool) {
        showSelectionBackground = show
    }
}
