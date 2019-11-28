import Foundation
import UIKit

class MultilineTextFieldCell: UITableViewCell, UITextViewDelegate {
    static let cellHeight: CGFloat = 125

    var onTextFieldChange:((_:UITextView) -> Void)?    // set this from outside to get notified about textfield changes

    lazy var descriptionField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isEnabled = false
        return textField
    }()

    lazy var textField: UITextView = {
        let textField = UITextView()
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = UIFont.systemFont(ofSize: 16)
        return textField
    }()

    lazy var placeholder: UILabel = {
        let placeholderLabel = UILabel()
        placeholderLabel.font = self.textField.font
        placeholderLabel.textColor = UIColor.lightGray
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.isHidden = !textField.text.isEmpty
        return placeholderLabel
    }()


    init(description: String, placeholder: String) {
        super.init(style: .value1, reuseIdentifier: nil)
        self.descriptionField.text = "\(description):"
        self.placeholder.text = placeholder
        selectionStyle = .none
        setupViews()
    }

    convenience init(descriptionID: String, placeholder: String) {
        self.init(description: String.localized(descriptionID), placeholder: placeholder)
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
        contentView.addConstraint(textField.constraintHeightTo(95))
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
