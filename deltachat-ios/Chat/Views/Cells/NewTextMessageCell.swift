import Foundation
import DcCore
import UIKit

class NewTextMessageCell: UITableViewCell {

    lazy var avatarView: InitialsBadge = {
        let view = InitialsBadge(size: 28)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        contentView.addConstraints([
            avatarView.constraintAlignTopTo(contentView, priority: .defaultLow),
            avatarView.constraintAlignLeadingTo(contentView),
            avatarView.constraintAlignBottomTo(contentView, priority: .defaultLow),
            avatarView.constraintCenterYTo(contentView, priority: .defaultHigh)
        ])
    }

    func update(msg: DcMsg) {
        textLabel?.text = msg.text
        avatarView.setName(msg.fromContact.displayName)
    }

    override func prepareForReuse() {
        textLabel?.text = nil
    }

    
}
