import Foundation
import UIKit

class BasicCell: UITableViewCell {

    static let reuseIdentifier = "basic_cell_reuse_identifier"

    private var fontSize: CGFloat {
        return UIFont.preferredFont(forTextStyle: .body).pointSize
    }
    private let maxFontSizeHorizontalLayout: CGFloat = 24
    private var layoutConstraints: [NSLayoutConstraint] = []
    var margin: CGFloat = 12

    public lazy var title: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 10), for: NSLayoutConstraint.Axis.horizontal)
        return label
    }()

    public lazy var value: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .darkGray
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: NSLayoutConstraint.Axis.horizontal)
        label.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1), for: NSLayoutConstraint.Axis.horizontal)
        label.textAlignment = .right
        return label
    }()

    public lazy var stackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true

        view.addArrangedSubview(title)
        view.addArrangedSubview(value)
        view.axis = .horizontal
        view.spacing = 10
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private func setupSubviews() {
        contentView.addSubview(stackView)
        contentView.removeConstraints(contentView.constraints)
               contentView.addConstraints([
                   stackView.constraintAlignLeadingTo(contentView, paddingLeading: margin),
                   stackView.constraintAlignTopTo(contentView, paddingTop: margin),
                   stackView.constraintAlignBottomTo(contentView, paddingBottom: margin),
                   stackView.constraintAlignTrailingTo(/*accessoryView ??*/ contentView, paddingTrailing: margin)
               ])
        updateViews()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            updateViews()
        }
    }

    public func updateViews() {
        if fontSize <= maxFontSizeHorizontalLayout {
            title.numberOfLines = 1
            value.numberOfLines = 1
            value.textAlignment = .right
            stackView.axis = .horizontal
            stackView.spacing = 10

        } else {
            title.numberOfLines = 0
            value.numberOfLines = 0
            value.textAlignment = .left
            stackView.axis = .vertical
            stackView.spacing = 0
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        title.text = nil
        value.text = nil
        title.attributedText = nil
        value.attributedText = nil

    }
}
