import UIKit

class TextFieldCell: UITableViewCell {
    private let placeholder: String

    var onTextFieldChange:((_:UITextField) -> Void)?	// set this from outside to get notified about textfield changes

    lazy var textField: UITextField = {
        let textField = UITextField()
        textField.textAlignment = .right
        // textField.enablesReturnKeyAutomatically = true
        textField.placeholder = self.placeholder
        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        return textField
    }()

    init(description: String, placeholder: String, delegate: UITextFieldDelegate? = nil) {
        self.placeholder = placeholder
        super.init(style: .value1, reuseIdentifier: nil)
        textLabel?.text = "\(description):"

        // see: https://stackoverflow.com/a/35903650
        // this makes the textField respect the trailing margin of
        // the table view cell
        selectionStyle = .none
        setupViews()
        textField.delegate = delegate
    }

    convenience init(descriptionID: String, placeholder: String, delegate: UITextFieldDelegate? = nil) {
        self.init(description: String.localized(descriptionID), placeholder: placeholder, delegate: delegate)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        let margins = contentView.layoutMarginsGuide
        let trailing = margins.trailingAnchor
        textField.trailingAnchor.constraint(equalTo: trailing).isActive = true
        textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        if let label = self.textLabel {
            textField.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 20).isActive = true
            // this will prevent the textfield from growing over the textLabel while typing
        } else {
            textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20).isActive = true
        }
    }

    override func setSelected(_ selected: Bool, animated _: Bool) {
        if selected {
            textField.becomeFirstResponder()
        }
    }

    @objc func textFieldChanged() {
        onTextFieldChange?(self.textField)
    }

    func getText() -> String? {
        if let text = textField.text {
            if text.isEmpty {
                return nil
            } else {
                return textField.text
            }
        } else {
            return nil
        }
    }

    func setText(text: String?) {
        textField.text = text
    }

    static func makeEmailCell(delegate: UITextFieldDelegate? = nil) -> TextFieldCell {
        let cell = TextFieldCell(description: String.localized("email_address"), placeholder: "you@example.com")
        cell.textField.keyboardType = .emailAddress
        // switch off quicktype
        cell.textField.autocorrectionType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.delegate = delegate
        return cell
    }

    static func makePasswordCell(delegate _: UITextFieldDelegate? = nil) -> TextFieldCell {
        let cell = TextFieldCell(description: String.localized("password"), placeholder: String.localized("password"))
        cell.textField.textContentType = UITextContentType.password
        cell.textField.isSecureTextEntry = true
        return cell
    }

    static func makeNameCell(delegate: UITextFieldDelegate? = nil) -> TextFieldCell {
        let cell = TextFieldCell(description: String.localized("name_desktop"), placeholder: String.localized("name_desktop"))
        cell.textField.autocapitalizationType = .words
        cell.textField.autocorrectionType = .no
        // .namePhonePad doesn't support autocapitalization
        // see: https://stackoverflow.com/a/36365399
        // therefore we use .default to capitalize the first character of the name
        cell.textField.keyboardType = .default
        cell.textField.delegate = delegate

        return cell
    }

    static func makeConfigCell(labelID: String, placeholderID: String, delegate: UITextFieldDelegate? = nil) -> TextFieldCell {
        let cell = TextFieldCell(description: String.localized(labelID), placeholder: String.localized(placeholderID))
        cell.textField.autocapitalizationType = .words
        cell.textField.autocorrectionType = .no
        // .namePhonePad doesn't support autocapitalization
        // see: https://stackoverflow.com/a/36365399
        // therefore we use .default to capitalize the first character of the name
        cell.textField.keyboardType = .default
        cell.textField.delegate = delegate
        return cell
    }
}
