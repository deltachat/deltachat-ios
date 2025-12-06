import UIKit
import DcCore

class TransportCell: UITableViewCell {
    static let reuseIdentifier = "TransportCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
