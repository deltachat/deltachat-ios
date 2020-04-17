import UIKit

/*
 cell that displays text and grows in size
*/

class TextCell: UITableViewCell {

    var content: String? {
        set {
            textLabel?.text = newValue
        }
        get {
            return textLabel?.text
        }
    }

    var intrinsicCellHeight: CGFloat {
        return intrinsicContentSize.height
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
        textLabel?.numberOfLines = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        guard let textLabel = self.textLabel else {
            return
        }
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
        textLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 0).isActive = true
        textLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor, constant: 0).isActive = true
        textLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: 0).isActive = true
    }
}
