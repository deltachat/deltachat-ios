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
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        contentView.addSubview(actionLabel)
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addConstraints([
            actionLabel.constraintAlignLeadingTo(contentView, paddingLeading: 12),
            actionLabel.constraintAlignTrailingTo(contentView, paddingTrailing: 12),
            actionLabel.constraintAlignTopTo(contentView, paddingTop: 12),
            actionLabel.constraintAlignBottomTo(contentView, paddingBottom: 12)

        ])
    }
}
