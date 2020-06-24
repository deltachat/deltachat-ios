import Foundation
import UIKit

class MultilineTextFieldCell: UITableViewCell, UITextViewDelegate {

    private static let padding: CGFloat = 16
    static var cellHeight: CGFloat {
        return UIFont.preferredFont(forTextStyle: .body).fontDescriptor.pointSize * 6 + MultilineTextFieldCell.padding
    }

    var onTextFieldChange:((_:UITextView) -> Void)?    // set this from outside to get notified about textfield changes

    lazy var descriptionField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isEnabled = false
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        return textField
    }()

    lazy var textField: UITextView = {
        let textField = UITextView()
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.backgroundColor = .none
        return textField
    }()

    lazy var placeholder: UILabel = {
        let placeholderLabel = UILabel()
        placeholderLabel.textColor = UIColor.lightGray
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        return placeholderLabel
    }()

    init(description: String, multilineText: String?, placeholder: String) {
        super.init(style: .value1, reuseIdentifier: nil)
        self.descriptionField.text = "\(description):"
        self.textField.text = multilineText
        self.placeholder.text = placeholder
        self.placeholder.isHidden = !textField.text.isEmpty
        selectionStyle = .none
        setupViews()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupViews() {
        contentView.addSubview(descriptionField)
        contentView.addSubview(textField)
        contentView.addSubview(placeholder)
        let margins = contentView.layoutMarginsGuide

        descriptionField.alignLeadingToAnchor(margins.leadingAnchor)
        descriptionField.alignTrailingToAnchor(margins.trailingAnchor)
        descriptionField.alignTopToAnchor(margins.topAnchor)

        textField.alignLeadingToAnchor(margins.leadingAnchor, paddingLeading: -5)
        textField.alignTrailingToAnchor(margins.trailingAnchor)
        let fontsize = textField.font!.fontDescriptor.pointSize
        contentView.addConstraint(textField.constraintHeightTo(fontsize * 4))
        textField.alignTopToAnchor(descriptionField.bottomAnchor)

        placeholder.alignLeadingToAnchor(margins.leadingAnchor)
        placeholder.alignTrailingToAnchor(textField.layoutMarginsGuide.trailingAnchor)
        placeholder.alignTopToAnchor(textField.layoutMarginsGuide.topAnchor)
    }

    override func setSelected(_ selected: Bool, animated _: Bool) {
        if selected {
            textField.becomeFirstResponder()
        }
    }

    func getText() -> String? {
        return textField.text
    }

    func setText(text: String?) {
        textField.text = text
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        onTextFieldChange?(self.textField)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        placeholder.isHidden = !(text.isEmpty && range.length == textView.text.count)
        return true
    }
}
