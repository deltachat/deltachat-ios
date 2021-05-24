import Foundation
import UIKit

class MultilineLabelCell: UITableViewCell {

    private lazy var textFieldHeightConstraint: NSLayoutConstraint = {
        return textField.constraintHeightTo(fourLinesHeight)
    }()

    private var fourLinesHeight: CGFloat {
        return UIFont.preferredFont(forTextStyle: .body).pointSize * 4
    }

    lazy var textField: UITextView = {
        let textField = UITextView()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.backgroundColor = .none
        textField.isEditable = false
        return textField
    }()

    init() {
        super.init(style: .value1, reuseIdentifier: nil)
        selectionStyle = .none
        setupViews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupViews() {
        contentView.addSubview(textField)
        let margins = contentView.layoutMarginsGuide

        textField.alignLeadingToAnchor(margins.leadingAnchor, paddingLeading: -5)
        textField.alignTrailingToAnchor(margins.trailingAnchor)
        contentView.addConstraint(textFieldHeightConstraint)
        textField.alignTopToAnchor(margins.topAnchor)
        textField.alignBottomToAnchor(margins.bottomAnchor)
    }

    func setText(text: String?) {
        textField.text = text
    }
}
