import UIKit
import DcCore

class ReactionsOverviewTableViewCell: UITableViewCell {
    static let reuseIdentifier = "ReactionsOverviewTableViewCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(emojis: [String], contact: DcContact) {
        textLabel?.text = "\(contact.displayName): \(emojis.joined(separator: ","))"
    }
}
