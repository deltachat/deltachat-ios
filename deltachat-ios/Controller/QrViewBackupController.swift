import Foundation
import UIKit
import DcCore
import SDWebImageSVGKitPlugin

class QrViewBackupController: UIViewController {

    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    private let dcBackupSender: DcBackupSender?
    var onDismissed: (() -> Void)?
    
    private lazy var qrContentView: UIImageView = {
        let svg = dcBackupSender?.qr_code(context: dcContext)
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        view.image = getQrImage(svg: svg)
        return view
    }()

    var qrCodeHint: String {
        willSet {
            let svg = dcBackupSender?.qr_code(context: dcContext)
            qrContentView.image = getQrImage(svg: svg)
            qrContentView.accessibilityHint = newValue
        }
    }
    private let chatId: Int

    init(dcContext: DcContext, dcAccounts: DcAccounts, chatId: Int? = 0, qrCodeHint: String?) {
        self.dcContext = dcContext
        self.dcAccounts = dcAccounts
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            self.dcAccounts.stopIo() // TODO: start again
            self.dcBackupSender = self.dcContext.send_backup(directory: documents[0], passphrase: nil)
        } else {
            logger.error("document directory not found")
            self.dcBackupSender = nil
        }
        self.chatId = chatId ?? 0
        self.qrCodeHint = qrCodeHint ?? ""
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("qrshow_title")
        setupSubviews()
        view.backgroundColor = DcColors.defaultBackgroundColor
    }

    override func viewDidDisappear(_ animated: Bool) {
        onDismissed?()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(qrContentView)
        let qrDefaultWidth = qrContentView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.75)
        qrDefaultWidth.priority = UILayoutPriority(500)
        qrDefaultWidth.isActive = true
        let qrMinWidth = qrContentView.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        qrMinWidth.priority = UILayoutPriority(999)
        qrMinWidth.isActive = true
        qrContentView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 1.05).isActive = true
        qrContentView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor).isActive = true
        qrContentView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
    }
    
    func getQrImage(svg: String?) -> UIImage? {
        if let svg = svg {
            let svgData = svg.data(using: .utf8)
            return SDImageSVGKCoder.shared.decodedImage(with: svgData, options: [:])
        }
        return nil
    }

}
