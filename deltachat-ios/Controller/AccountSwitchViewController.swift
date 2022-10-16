import UIKit
import DcCore

class AccountSwitchViewController: UITableViewController {
    

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }
    
    private func setupSubviews() {
        title = String.localized("switch_account")
        tableView.register(AccountCell.self, forCellReuseIdentifier: AccountCell.reuseIdentifier)
        tableView.rowHeight = AccountCell.cellHeight
        tableView.separatorStyle = .none
    }
}

class AccountCell: UITableViewCell {

    static let reuseIdentifier = "accountCell_reuse_identifier"
    static var cellHeight: CGFloat {
        let textHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize + UIFont.preferredFont(forTextStyle: .subheadline).pointSize + 24
        if textHeight > 74.5 {
            return textHeight
        }
        return 74.5
    }

    var isLargeText: Bool {
        return UIFont.preferredFont(forTextStyle: .body).pointSize > 36
    }

    lazy var accountAvatar: InitialsBadge = {
        let avatar = InitialsBadge(size: 52, accessibilityLabel: "")
        return avatar
    }()

    lazy var accountName: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    func setupSubviews() {
        addSubview(accountAvatar)
        addSubview(label)
        //addSubview(
    }

    public func updateCell(dcContext: DcContext) {
        let accountId = dcContext.id
        let title = dcContext.displayname ?? dcContext.addr ?? ""
        let contact = dcContext.getContact(id: Int(DC_CONTACT_ID_SELF))
        accountAvatar.setColor(contact.color)
        accountAvatar.setName(title)
        if let image = contact.profileImage {
            accountAvatar.setImage(image)
        }
    }
}
