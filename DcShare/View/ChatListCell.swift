import Foundation
import UIKit
import DcCore

class ChatListCell: UITableViewCell {

    let badgeSize: CGFloat = 54

    lazy var avatar: InitialsBadge = {
        let badge = InitialsBadge(size: badgeSize)
        badge.setColor(UIColor.lightGray)
        badge.isAccessibilityElement = false
        return badge
    }()

    lazy var stackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .leading
        stackView.clipsToBounds = true
        return stackView
    }()

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = DcColors.middleGray
        label.lineBreakMode = .byTruncatingTail
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = DcColors.contactCellBackgroundColor
        contentView.backgroundColor = DcColors.contactCellBackgroundColor
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        let margin: CGFloat = 10

        avatar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatar)

        contentView.addConstraints([
            avatar.constraintWidthTo(badgeSize),
            avatar.constraintHeightTo(badgeSize),
            avatar.constraintAlignLeadingTo(contentView, paddingLeading: badgeSize / 4),
            avatar.constraintCenterYTo(contentView),
        ])

        contentView.addSubview(stackView)
        contentView.addConstraints([
            stackView.constraintCenterYTo(contentView),
            stackView.constraintToTrailingOf(avatar, paddingLeading: margin),
            stackView.constraintAlignTrailingTo(contentView),
        ])
    }

    private func setImage(_ img: UIImage) {
        avatar.setImage(img)
    }

    private func resetBackupImage() {
        avatar.setColor(UIColor.clear)
        avatar.setName("")
    }

    private func setBackupImage(name: String, color: UIColor) {
        avatar.setColor(color)
        avatar.setName(name)
    }

    private func setColor(_ color: UIColor) {
        avatar.setColor(color)
    }

    // use this update-method to update cell in cellForRowAt whenever it is possible - other set-methods will be set private in progress
    func updateCell(cellViewModel: AvatarCellViewModel) {
        // subtitle
        switch cellViewModel.type {
        case .chat(let chatData):
            let chat = cellViewModel.dcContext.getChat(chatId: chatData.chatId)
            titleLabel.attributedText = cellViewModel.title.boldAt(indexes: cellViewModel.titleHighlightIndexes, fontSize: titleLabel.font.pointSize)
            if let img = chat.profileImage {
                resetBackupImage()
                setImage(img)
            } else {
                setBackupImage(name: chat.name, color: chat.color)
            }
            subtitleLabel.attributedText = nil
            let recentlySeen = DcUtils.showRecentlySeen(context: cellViewModel.dcContext, chat: chat)
            avatar.setRecentlySeen(recentlySeen)

        case .contact(let contactData):
            let contact = cellViewModel.dcContext.getContact(id: contactData.contactId)
            titleLabel.attributedText = cellViewModel.title.boldAt(indexes: cellViewModel.titleHighlightIndexes, fontSize: titleLabel.font.pointSize)
            if let profileImage = contact.profileImage {
                avatar.setImage(profileImage)
            } else {
                setBackupImage(name: cellViewModel.title, color: contact.color)
            }
            avatar.setRecentlySeen(contact.wasSeenRecently)
            subtitleLabel.attributedText = cellViewModel.subtitle.boldAt(indexes: cellViewModel.subtitleHighlightIndexes,
                                                                         fontSize: subtitleLabel.font.pointSize)
        default:
            return

        }
    }
}
