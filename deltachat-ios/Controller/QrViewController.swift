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
    private let moreButton: UIBarButtonItem

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

        let moreButtonImage: UIImage?
        if #available(iOS 13.0, *) {
            moreButtonImage = UIImage(systemName: "ellipsis.circle")
        } else {
            moreButtonImage = UIImage(named: "ic_more")
        }

        moreButton = UIBarButtonItem(image: moreButtonImage, style: .plain, target: nil, action: nil)

        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = DcColors.defaultBackgroundColor

        title = String.localized("qrshow_title")
        navigationItem.rightBarButtonItem = moreButton
        moreButton.action = #selector(QrViewController.showMoreOptions(_:))
        moreButton.target = self
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
        let orientation = UIApplication.shared.statusBarOrientation

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

    // Only relevant for GroupChatDetails, for QR-Code-Tab, this gets handled by QrPageController
    @objc private func showMoreOptions(_ sender: Any) {
        let alert = UIAlertController(title: String.localized("qrshow_title"), message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("menu_share"), style: .default, handler: share(_:)))
        alert.addAction(UIAlertAction(title: String.localized("menu_copy_to_clipboard"), style: .default, handler: copyToClipboard(_:)))
        alert.addAction(UIAlertAction(title: String.localized("withdraw_qr_code"), style: .default, handler: withdrawQrCode(_:)))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func share(_ action: UIAlertAction) {
        if let inviteLink = Utils.getInviteLink(context: dcContext, chatId: chatId) {
            Utils.share(url: inviteLink, parentViewController: self, sourceItem: moreButton)
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
