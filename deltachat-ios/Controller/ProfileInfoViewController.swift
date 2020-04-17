import UIKit
import DcCore

class ProfileInfoViewController: UITableViewController {

    private lazy var headerCell: TextCell = {
        let cell = TextCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("qraccount_success_enter_name")
        cell.textLabel?.numberOfLines = 0
        return cell
    }()

    private lazy var emailCell: TextFieldCell = {
        let cell = TextFieldCell(description: "Meine Email Adresse", placeholder: "Meine Email")
        cell.setText(text: dcContext.addr)
        return cell
    }()

    private lazy var avatarCell: UITableViewCell = {
        let cell = AvatarSelectionCell(context: self.dcContext)
        cell.onAvatarTapped = avatarTapped
        return cell
    }()

    private lazy var nameCell: TextFieldCell = {
        let cell = TextFieldCell(description: String.localized("pref_your_name"), placeholder: String.localized("pref_your_name"))
        cell.setText(text: dcContext.displayname)
        return cell
    }()

    private lazy var cells = [headerCell, avatarCell, nameCell]

    private let dcContext: DcContext

    init(context: DcContext) {
        self.dcContext = context
        super.init(style: .grouped)
        tableView.estimatedRowHeight = Constants.defaultCellHeight
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("pref_profile_info_headline")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        let cell = cells[indexPath.row]

        if let textCell = cell as? TextCell {
            return textCell.intrinsicCellHeight
        }

        if cell is AvatarSelectionCell {
            return AvatarSelectionCell.cellHeight
        }

        return Constants.defaultCellHeight
    }

    private func avatarTapped() {

    }

}

class TextCell: UITableViewCell {

    var intrinsicCellHeight: CGFloat {
        return intrinsicContentSize.height
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
        textLabel?.numberOfLines = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        guard let textLabel = self.textLabel else {
            return
        }
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
        textLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 0).isActive = true
        textLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor, constant: 0).isActive = true
        textLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: 0).isActive = true
    }

}
