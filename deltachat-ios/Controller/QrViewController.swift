import Foundation
import UIKit
import DcCore

class QrViewController: UIViewController {

    private let dcContext: DcContext

    private var contact: DcContact? {
        // This is nil if we do not have an account setup yet
        if !dcContext.isConfigured() {
            return nil
        }
        return DcContact(id: Int(DC_CONTACT_ID_SELF))
    }

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var qrContentView: QrViewContentView = {
        let view = QrViewContentView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK:  - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("qr_code")
        setupSubviews()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(qrContentView)

        let frameGuide = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide

        frameGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        frameGuide.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        frameGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        frameGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        contentGuide.leadingAnchor.constraint(equalTo: qrContentView.leadingAnchor).isActive = true
        contentGuide.topAnchor.constraint(equalTo: qrContentView.topAnchor).isActive = true
        contentGuide.trailingAnchor.constraint(equalTo: qrContentView.trailingAnchor).isActive = true
        contentGuide.bottomAnchor.constraint(equalTo: qrContentView.bottomAnchor).isActive = true

        // this enables vertical scrolling
        frameGuide.widthAnchor.constraint(equalTo: contentGuide.widthAnchor).isActive = true
    }

    // MARK: - actions
    private func displayNewChat(contactId: Int) {
        let chatId = dcContext.createChatByContactId(contactId: contactId)
        let chatVC = ChatViewController(dcContext: dcContext, chatId: Int(chatId))

        chatVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

// MARK: - QrViewContentView
class QrViewContentView: UIView {

}

/*
 private func createQRCodeCell() -> UITableViewCell {
     let cell = UITableViewCell(style: .default, reuseIdentifier: "qrCodeCell")
     let qrCode = createQRCodeView()
     let infolabel = createInfoLabel()

     cell.contentView.addSubview(qrCode)
     cell.contentView.addSubview(infolabel)
     cell.selectionStyle = .none

     let qrCodeConstraints = [qrCode.constraintAlignTopTo(cell.contentView, paddingTop: 25),
                              qrCode.constraintCenterXTo(cell.contentView)]
     let infoLabelConstraints = [infolabel.constraintToBottomOf(qrCode, paddingTop: 25),
                                 infolabel.constraintAlignLeadingTo(cell.contentView, paddingLeading: 8),
                                 infolabel.constraintAlignTrailingTo(cell.contentView, paddingTrailing: 8)]
     cell.contentView.addConstraints(qrCodeConstraints)
     cell.contentView.addConstraints(infoLabelConstraints)
     return cell
 }

 private func createInfoLabel() -> UIView {
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

 private func createQRCodeView() -> UIView {
     let width: CGFloat = 230
     let frame = CGRect(origin: .zero, size: .init(width: width, height: width))
     let imageView = QRCodeView(frame: frame)
     if let qrCode = dcContext.getSecurejoinQr(chatId: 0) {
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

 */
