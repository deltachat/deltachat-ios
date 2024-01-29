import Foundation
import UIKit
import DcCore
import SDWebImageSVGKitPlugin

class QrViewController: UIViewController {

    private let dcContext: DcContext
    var onDismissed: (() -> Void)?
    
    private lazy var qrContentView: UIImageView = {
        let svg = dcContext.getSecurejoinQrSVG(chatId: chatId)
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        view.image = getQrImage(svg: svg)
        return view
    }()

    private lazy var moreButton: UIBarButtonItem = {
        let image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "ellipsis.circle")
        } else {
            image = UIImage(named: "ic_more")
        }
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(showMoreOptions))
    }()

    var qrCodeHint: String {
        willSet {
            let svg = dcContext.getSecurejoinQrSVG(chatId: chatId)
            qrContentView.image = getQrImage(svg: svg)
            qrContentView.accessibilityHint = newValue
        }
    }
    private let chatId: Int

    init(dcContext: DcContext, chatId: Int? = 0, qrCodeHint: String?) {
        self.dcContext = dcContext
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
        navigationItem.rightBarButtonItem = moreButton
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

    // MARK: - actions
    @objc private func showMoreOptions() {
        let alert = UIAlertController(title: String.localized("qrshow_title"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("menu_share"), style: .default, handler: share(_:)))
        alert.addAction(UIAlertAction(title: String.localized("menu_copy_to_clipboard"), style: .default, handler: copyToClipboard(_:)))
        alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .default, handler: withdrawQrCode(_:)))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func share(_ action: UIAlertAction) {
        if let inviteLink = Utils.getInviteLink(context: dcContext, chatId: chatId) {
            FilesViewController.share(url: inviteLink, parentViewController: self)
        }
    }

    @objc func copyToClipboard(_ action: UIAlertAction) {
        UIPasteboard.general.string = Utils.getInviteLink(context: dcContext, chatId: chatId)
    }

    @objc func withdrawQrCode(_ action: UIAlertAction) {
        let groupName = dcContext.getChat(chatId: chatId).name
        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("withdraw_verifygroup_explain"), groupName),
                                      message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .default))
        alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            guard let code = dcContext.getSecurejoinQr(chatId: self.chatId) else { return }
            _ = self.dcContext.setConfigFromQR(qrCode: code)
            self.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
    }
}
