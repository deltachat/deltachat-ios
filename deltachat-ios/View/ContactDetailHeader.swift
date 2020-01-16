import UIKit

class ContactDetailHeader: AvatarTextCell {
    init() {
        super.init(style: .default, reuseIdentifier: nil)
        let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)
        backgroundColor = bg
        selectionStyle = .none
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateDetails(title: String?, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}
