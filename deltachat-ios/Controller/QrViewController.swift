import Foundation
import UIKit
import DcCore
import SDWebImageSVGKitPlugin

class QrViewController: UIViewController {

    private let dcContext: DcContext

    private let contentStackView: UIStackView
    private let contentScrollView: UIScrollView
    private let qrContentView: UIImageView
    private let shareLinkButton: UIButton

    private lazy var moreButton: UIBarButtonItem = {
        let moreButtonImage = UIImage(systemName: "ellipsis.circle")
        return UIBarButtonItem(image: moreButtonImage, menu: showMoreOptions())
    }()

    var verticalCenterConstraint: NSLayoutConstraint?
    var contentTopAnchor: NSLayoutConstraint?
    var contentBottomAnchor: NSLayoutConstraint?

    var qrCodeHint: String {
        willSet {
            let svg = dcContext.getSecurejoinQrSVG(chatId: chatId)
            qrContentView.image = getQrImage(svg: svg)
            qrContentView.accessibilityHint = newValue
        }
    }
    private let chatId: Int

    init(dcContext: DcContext, chatId: Int = 0, qrCodeHint: String = "") {
        self.dcContext = dcContext
        self.chatId = chatId
        self.qrCodeHint = qrCodeHint

        qrContentView = UIImageView()
        qrContentView.contentMode = .scaleAspectFit
        qrContentView.translatesAutoresizingMaskIntoConstraints = false

        shareLinkButton = UIButton(type: .system)
        shareLinkButton.setTitle(String.localized("share_invite_link"), for: .normal)
        shareLinkButton.translatesAutoresizingMaskIntoConstraints = false

        contentStackView = UIStackView(arrangedSubviews: [qrContentView, shareLinkButton, UIView()])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.spacing = 16

        contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStackView)

        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = DcColors.defaultBackgroundColor

        title = String.localized("qrshow_title")
        navigationItem.rightBarButtonItem = moreButton
        shareLinkButton.addTarget(self, action: #selector(QrViewController.shareInviteLink(_:)), for: .touchUpInside)
        shareLinkButton.setTitleColor(DcColors.primary, for: .normal)

        let svg = dcContext.getSecurejoinQrSVG(chatId: chatId)
        qrContentView.image = getQrImage(svg: svg)

        view.addSubview(contentScrollView)

        setupConstraints()
    }

    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {

        let qrImageRatio: CGFloat
        if let image = qrContentView.image {
            qrImageRatio = image.size.height / image.size.width
        } else {
            qrImageRatio = 1
        }

        verticalCenterConstraint = contentStackView.centerYAnchor.constraint(equalTo: contentScrollView.centerYAnchor)
        contentTopAnchor = contentStackView.topAnchor.constraint(equalTo: contentScrollView.topAnchor, constant: 16)
        contentBottomAnchor = contentScrollView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: 16)

        let constraints = [
            qrContentView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.75),
            qrContentView.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            qrContentView.heightAnchor.constraint(equalTo: qrContentView.widthAnchor, multiplier: qrImageRatio),

            contentScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: contentScrollView.trailingAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: contentScrollView.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: contentScrollView.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor),

            contentStackView.centerXAnchor.constraint(equalTo: contentScrollView.centerXAnchor),
        ]

        traitCollectionDidChange(traitCollection)
        NSLayoutConstraint.activate(constraints)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard let orientation = UIApplication.shared.orientation else { return }

        switch orientation {
        case .portrait, .portraitUpsideDown:
            verticalCenterConstraint?.isActive = true
            contentTopAnchor?.isActive = false
            contentBottomAnchor?.isActive = false
        case .landscapeLeft, .landscapeRight:
            verticalCenterConstraint?.isActive = false
            contentTopAnchor?.isActive = true
            contentBottomAnchor?.isActive = true
        case .unknown:
            // do nothing
            break
        @unknown default:
            break
        }
    }

    // MARK: - lifecycle
    func getQrImage(svg: String?) -> UIImage? {
        guard let svg else { return nil }

        let svgData = svg.data(using: .utf8)
        let image = SDImageSVGKCoder.shared.decodedImage(with: svgData, options: [:])
        return image
    }

    // MARK: - Actions
    @objc private func shareInviteLink(_ sender: UIButton) {
        guard let inviteLink = Utils.getInviteLink(context: dcContext, chatId: chatId), let inviteLinkURL = URL(string: inviteLink) else { return }

        Utils.share(url: inviteLinkURL, parentViewController: self, sourceView: sender)
    }

    // Only relevant for group profiles. For QR-Code-Tab, this gets handled by QrPageController
    private func showMoreOptions() -> UIMenu {
        let actions = [
            UIAction(title: String.localized("menu_share"), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.share()
            },
            UIAction(title: String.localized("menu_copy_to_clipboard"), image: UIImage(systemName: "document.on.document")) { [weak self] _ in
                self?.copyToClipboard()
            },
            UIAction(title: String.localized("withdraw_qr_code"), image: UIImage(systemName: "trash"), attributes: [.destructive]) { [weak self] _ in
                self?.withdrawQrCode()
            },
        ]
        return UIMenu(children: actions)
    }

    func share() {
        if let inviteLink = Utils.getInviteLink(context: dcContext, chatId: chatId) {
            Utils.share(url: inviteLink, parentViewController: self, sourceItem: moreButton)
        }
    }

    func copyToClipboard() {
        UIPasteboard.general.string = Utils.getInviteLink(context: dcContext, chatId: chatId)
    }

    func withdrawQrCode() {
        let chat = dcContext.getChat(chatId: chatId)
        let msg = String.localizedStringWithFormat(String.localized(chat.isOutBroadcast ? "withdraw_joinbroadcast_explain" : "withdraw_verifygroup_explain"), chat.name)
        let alert = UIAlertController(title: msg, message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            guard let code = dcContext.getSecurejoinQr(chatId: self.chatId) else { return }
            _ = self.dcContext.setConfigFromQR(qrCode: code)
            self.navigationController?.popViewController(animated: true)
        }))
        present(alert, animated: true)
    }
}
