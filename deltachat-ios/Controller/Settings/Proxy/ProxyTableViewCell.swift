import UIKit

class ProxyTableViewCell: UITableViewCell {
    static let reuseIdentifier = "ProxyTableViewCell"

    // make it look like the Android-version

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        textLabel?.numberOfLines = 0
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
