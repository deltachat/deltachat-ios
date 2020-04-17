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

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = DcColors.defaultTextColor
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: NSLayoutConstraint.Axis.horizontal)
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

        contentView.addSubview(titleLabel)
        contentView.addConstraints([
            titleLabel.constraintCenterYTo(contentView),
            titleLabel.constraintToTrailingOf(avatar, paddingLeading: margin),
            titleLabel.constraintAlignTrailingTo(contentView)
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
    func updateCell(chatId: Int) {
        let chat = DcContext.shared.getChat(chatId: chatId)
        titleLabel.text = chat.name

        if chat.visibility == DC_CHAT_VISIBILITY_PINNED {
            backgroundColor = DcColors.deaddropBackground
            contentView.backgroundColor = DcColors.deaddropBackground
        } else {
            backgroundColor = DcColors.contactCellBackgroundColor
            contentView.backgroundColor = DcColors.contactCellBackgroundColor
        }

        if let img = chat.profileImage {
            resetBackupImage()
            setImage(img)
        } else {
            setBackupImage(name: chat.name, color: chat.color)
        }
    }
}
