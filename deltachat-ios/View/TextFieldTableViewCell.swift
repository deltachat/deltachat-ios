import UIKit

internal class TextFieldTableViewCell: UITableViewCell {
    static let identifier = "TextFieldTableViewCellIdentifier"

    var mainLabel = UILabel()
    var textField = UITextField()

    // MARK: - View lifecycle

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        mainLabel.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainLabel)
        contentView.addSubview(textField)

        NSLayoutConstraint.activate([
            mainLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainLabel.widthAnchor.constraint(equalToConstant: 200),
            mainLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textField.widthAnchor.constraint(equalToConstant: 50),
        ])

        textField.textAlignment = .right
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
