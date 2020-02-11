import UIKit

// a cell with a centered label in system blue

class ActionCell: UITableViewCell {

    static let reuseIdentifier = "action_cell_reuse_identifier"

    var actionTitle: String? {
        didSet {
            actionLabel.text = actionTitle
        }
    }

    var actionColor: UIColor? {
        didSet {
            actionLabel.textColor = actionColor ?? UIColor.systemBlue
        }
    }

    private lazy var actionLabel: UILabel = {
        let label = UILabel()
        label.text = actionTitle
        label.textColor = UIColor.systemBlue
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
        selectionStyle = .none
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    private func setupSubviews() {
        contentView.addSubview(actionLabel)
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 0).isActive = true
        actionLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
    }
}
