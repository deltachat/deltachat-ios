import UIKit
import DcCore

class ProxyTableViewCell: UITableViewCell {
    static let reuseIdentifier = "ProxyTableViewCell"

    // make it look like the Android-version

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

        textLabel?.numberOfLines = 0
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with proxyUrlString: String, dcContext: DcContext) {
        let parsed = dcContext.checkQR(qrCode: proxyUrlString)

        let host = parsed.text1
        let proxyProtocol = proxyUrlString.components(separatedBy: ":").first
        textLabel?.text = host
        detailTextLabel?.text = proxyProtocol
    }
}
