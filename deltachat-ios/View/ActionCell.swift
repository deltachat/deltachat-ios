import UIKit

// a cell with a centered label in system blue

class ActionCell: UITableViewCell {

    static let reuseIdentifier = "action_cell_reuse_identifier"

    var actionTitle: String? {
        didSet {
            textLabel?.text = actionTitle
        }
    }

    var actionColor: UIColor? {
        didSet {
            textLabel?.textColor = actionColor ?? UIColor.systemBlue
            if let imageView {
                imageView.tintColor = actionColor ?? UIColor.systemBlue
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textLabel?.textColor = UIColor.systemBlue
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
