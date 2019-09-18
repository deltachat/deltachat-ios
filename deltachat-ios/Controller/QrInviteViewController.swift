import Foundation
import UIKit

class QrInviteViewController: UITableViewController {
    private let rowQRCode = 0
    private let rowDescription = 1

    let dcContext: DcContext
    let chatId: Int
    var contact: DcContact? {
        // This is nil if we do not have an account setup yet
        if !DcConfig.configured {
            return nil
        }
        return DcContact(id: Int(DC_CONTACT_ID_SELF))
    }

    init(dcContext: DcContext, chatId: Int) {
        self.dcContext = dcContext
        self.chatId = chatId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("qrshow_join_contact_title")
        tableView.separatorStyle = .none
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        switch row {
        case rowQRCode:
            return createQRCodeCell()
        case rowDescription:
            return createInfoLabelCell()
        default:
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        NavBarUtils.setSmallTitle(navigationController: navigationController)
    }

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case rowQRCode:
            return 225
        case rowDescription:
            return 40
        default:
            return 10
        }
    }

    private func createQRCodeCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "qrCodeCell")
        let qrCode = createQRCodeView()
        cell.contentView.addSubview(qrCode)
        cell.selectionStyle = .none

        let qrCodeConstraints = [qrCode.constraintAlignTopTo(cell.contentView, paddingTop: 50),
                                 qrCode.constraintCenterXTo(cell.contentView)]
        cell.contentView.addConstraints(qrCodeConstraints)
        return cell
    }

    private func createInfoLabelCell() -> UITableViewCell {
        let label = createDescriptionView()
        let cell = UITableViewCell(style: .default, reuseIdentifier: "qrCodeCell")
        cell.contentView.addSubview(label)
        cell.selectionStyle = .none
        let labelConstraints = [label.constraintCenterXTo(cell.contentView),
                                label.constraintAlignTopTo(cell.contentView, paddingTop: 45),
                                label.constraintAlignLeadingTo(cell.contentView, paddingLeading: 30),
                                label.constraintAlignTrailingTo(cell.contentView, paddingTrailing: 30)]
         cell.contentView.addConstraints(labelConstraints)
        return cell
    }

    private func createQRCodeView() -> UIView {
        let width: CGFloat = 200
        let frame = CGRect(origin: .zero, size: .init(width: width, height: width))
        let imageView = QRCodeView(frame: frame)
        if let qrCode = dcContext.getSecurejoinQr(chatId: chatId) {
            imageView.generateCode(
                qrCode,
                foregroundColor: .darkText,
                backgroundColor: .white
            )
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: width).isActive = true
        return imageView
    }

    private func createDescriptionView() -> UIView {
        let label = UILabel.init()
        label.translatesAutoresizingMaskIntoConstraints = false
        if let contact = contact {
            label.text = String.localizedStringWithFormat(String.localized("qrshow_join_contact_hint"), contact.email)
        }
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }
}
