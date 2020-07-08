import UIKit

class TextFieldCell: UITableViewCell {

    private let maxFontSizeHorizontalLayout: CGFloat = 30

    var placeholderVal: String
    var placeholder: String? {
        set {
            placeholderVal = newValue ?? ""
            configureTextFieldPlaceholder()
        }
        get {
            return placeholderVal
        }
    }

    private var fontSize: CGFloat {
        return UIFont.preferredFont(forTextStyle: .body).pointSize
    }

    private var preferValue: Bool {
        set {
            textField.setContentCompressionResistancePriority( newValue ? .defaultHigh : .defaultLow, for: .horizontal)
            title.setContentCompressionResistancePriority( newValue ? .defaultLow : .defaultHigh, for: .horizontal)
        }
        get {
            textField.contentCompressionResistancePriority(for: .horizontal) == .defaultHigh
        }
    }

    public var preferValueOnWrite: Bool

    private var customConstraints: [NSLayoutConstraint] = []

    var onTextFieldChange:((_:UITextField) -> Void)?	// set this from outside to get notified about textfield changes


    public lazy var title: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .darkGray
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    lazy var textField: UITextField = {
        let textField = UITextField()
        textField.textAlignment = .right
        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.translatesAutoresizingMaskIntoConstraints = false
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
        preferValueOnWrite = true
        placeholderVal = placeholder
        super.init(style: .default, reuseIdentifier: nil)
        title.text = "\(description):"

        // see: https://stackoverflow.com/a/35903650
        // this makes the textField respect the trailing margin of
        // the table view cell
        selectionStyle = .none
        setupViews()
        textField.delegate = delegate
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
        preferValue = preferValueOnWrite
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
        let cell = TextFieldCell(description: String.localized("email_address"), placeholder: "you@example.org")
        cell.textField.keyboardType = .emailAddress
        // switch off quicktype
        cell.textField.autocorrectionType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.delegate = delegate
        cell.preferValueOnWrite = true
        return cell
    }

    static func makePasswordCell(delegate _: UITextFieldDelegate? = nil) -> TextFieldCell {
        let cell = TextFieldCell(description: String.localized("password"), placeholder: String.localized("existing_password"))
        cell.textField.textContentType = UITextContentType.password
        cell.textField.isSecureTextEntry = true
        cell.preferValueOnWrite = true
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
