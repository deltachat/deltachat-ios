import UIKit
import DcCore

class ProxyTableViewCell: UITableViewCell {

    static let reuseIdentifier = "ProxyTableViewCell"

    let hostLabel: UILabel
    let protocolLabel: UILabel
    let connectionLabel: UILabel

    private let contentStackView: UIStackView
    private let subtitleStackView: UIStackView

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        hostLabel = UILabel()
        protocolLabel = UILabel()

        let detailsColor = UIColor.secondaryLabel
        protocolLabel.textColor = detailsColor
        protocolLabel.font = UIFont.preferredFont(forTextStyle: .footnote)

        connectionLabel = UILabel()
        connectionLabel.textColor = detailsColor
        connectionLabel.font = UIFont.preferredFont(forTextStyle: .footnote)

        subtitleStackView = UIStackView(
            arrangedSubviews: [
                UIView.borderedView(around: protocolLabel, borderWidth: 1, borderColor: detailsColor, cornerRadius: 2, padding: NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)),
                connectionLabel,
                UIView()
            ]
        )
        subtitleStackView.translatesAutoresizingMaskIntoConstraints = false
        subtitleStackView.spacing = 4

        contentStackView = UIStackView(arrangedSubviews: [hostLabel, subtitleStackView])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 6

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(contentStackView)

        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 8),
            contentView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: 8),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    func configure(with proxyUrlString: String, dcContext: DcContext, connectionStateText: String?) {
        let parsed = dcContext.checkQR(qrCode: proxyUrlString)

        let host = parsed.text1
        let proxyProtocol = proxyUrlString.components(separatedBy: ":").first

        hostLabel.text = host
        protocolLabel.text = proxyProtocol

        if let connectionStateText {
            connectionLabel.text = connectionStateText
            connectionLabel.isHidden = false
        } else {
            connectionLabel.isHidden = true
        }
    }
}
