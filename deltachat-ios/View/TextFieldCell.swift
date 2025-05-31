import UIKit
import DcCore

class TextFieldCell: UITableViewCell {

    private let maxFontSizeHorizontalLayout: CGFloat = 30

    private var placeholderVal: String
    var placeholder: String? {
        get {
            return placeholderVal
        }
        set {
            placeholderVal = newValue ?? ""
            configureTextFieldPlaceholder()
        }
    }

    private var fontSize: CGFloat {
        return UIFont.preferredFont(forTextStyle: .body).pointSize
    }

    private var preferValue: Bool {
        get {
            textField.contentCompressionResistancePriority(for: .horizontal) == .defaultHigh
        }
        set {
            textField.setContentCompressionResistancePriority( newValue ? .defaultHigh : .defaultLow, for: .horizontal)
            title.setContentCompressionResistancePriority( newValue ? .defaultLow : .defaultHigh, for: .horizontal)
        }
    }

    private var customConstraints: [NSLayoutConstraint] = []

    var onTextFieldChange: ((_: UITextField) -> Void)?	// set this from outside to get notified about textfield changes


    public lazy var title: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = DcColors.defaultTextColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // use textFieldDelegate instead of textfield.delegate if you want to set a delegate from outside
    public weak var textFieldDelegate: UITextFieldDelegate?
    lazy var textField: UITextField = {
        let textField = UITextField()
        textField.textAlignment = .right
        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        return textField
    }()

    public lazy var stackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.addArrangedSubview(title)
        view.addArrangedSubview(textField)
        view.axis = .horizontal
        view.spacing = 10
        return view
    }()
    
    init(description: String, placeholder: String, delegate: UITextFieldDelegate? = nil) {
        placeholderVal = placeholder
        super.init(style: .default, reuseIdentifier: nil)
        title.text = "\(description):"

        // see: https://stackoverflow.com/a/35903650
        // this makes the textField respect the trailing margin of
        // the table view cell
        selectionStyle = .none
        setupViews()
        textFieldDelegate = delegate
        textField.placeholder = placeholder
        preferValue = false
    }

    convenience init(descriptionID: String, placeholder: String, delegate: UITextFieldDelegate? = nil) {
        self.init(description: String.localized(descriptionID), placeholder: placeholder, delegate: delegate)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let margins = contentView.layoutMarginsGuide
        contentView.addSubview(stackView)
        stackView.alignTopToAnchor(margins.topAnchor)
        stackView.alignBottomToAnchor(margins.bottomAnchor)
        stackView.alignLeadingToAnchor(margins.leadingAnchor)
        stackView.alignTrailingToAnchor(margins.trailingAnchor)
        updateViews()
    }

    override func setSelected(_ selected: Bool, animated _: Bool) {
        if selected {
            textField.becomeFirstResponder()
        }
    }

    @objc func textFieldChanged() {
        configureTextFieldPlaceholder()
        onTextFieldChange?(self.textField)
    }

    func configureTextFieldPlaceholder() {
        if let textFieldText = textField.text, !textFieldText.isEmpty {
            textField.placeholder = nil
        } else {
            textField.placeholder = placeholderVal
        }
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

    func useFullWidth() {
        title.isHidden = true
        textField.textAlignment = .left
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if previousTraitCollection?.preferredContentSizeCategory !=
            traitCollection.preferredContentSizeCategory {
            updateViews()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        title.text = nil
        title.attributedText = nil
        textField.text = nil
    }

    private func updateViews() {
        if fontSize <= maxFontSizeHorizontalLayout {
            stackView.axis = .horizontal
            title.numberOfLines = 1
            textField.textAlignment = .right
        } else {
            stackView.axis = .vertical
            title.numberOfLines = 1
            textField.textAlignment = .left
        }
    }

    static func makeEmailCell(delegate: UITextFieldDelegate? = nil) -> TextFieldCell {
        let cell = TextFieldCell(description: String.localized("email_address"), placeholder: "name@example.org")
        cell.textField.keyboardType = .emailAddress
        // switch off quicktype
        cell.textField.autocorrectionType = .no
        cell.textField.autocapitalizationType = .none
        cell.textFieldDelegate = delegate
        return cell
    }

    static func makePasswordCell(delegate: UITextFieldDelegate? = nil) -> TextFieldCell {
        let cell = TextFieldCell(description: String.localized("existing_password"), placeholder: String.localized("password"))
        cell.textField.textContentType = UITextContentType.password
        cell.textField.isSecureTextEntry = true
        cell.textFieldDelegate = delegate
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
        cell.textFieldDelegate = delegate

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
        cell.textFieldDelegate = delegate
        return cell
    }
}

extension TextFieldCell: UITextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let delegate = textFieldDelegate {
            delegate.textFieldDidEndEditing?(textField)
        }
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        if let delegate = textFieldDelegate {
            delegate.textFieldDidChangeSelection?(textField)
        }
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if let delegate = textFieldDelegate, let result = delegate.textFieldShouldClear?(textField) {
            return result
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let delegate = textFieldDelegate, let result = delegate.textFieldShouldReturn?(textField) {
            return result
        }
        return true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        preferValue = true
        if let delegate = textFieldDelegate, let result = delegate.textFieldShouldBeginEditing?(textField) {
            return result
        }
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        preferValue = false
        if let delegate = textFieldDelegate, let result = delegate.textFieldShouldEndEditing?(textField) {
            return result
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if let delegate = textFieldDelegate {
            delegate.textFieldDidEndEditing?(textField)
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let delegate = textFieldDelegate, let result = delegate.textField?(textField, shouldChangeCharactersIn: range, replacementString: string) {
            return result
        }
        return true
    }

}
