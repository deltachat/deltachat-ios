import UIKit
import DcCore
import SDWebImageSVGKitPlugin

class ShareProxyViewController: UIViewController {
    private let dcContext: DcContext

    private let contentStackView: UIStackView
    private let contentScrollView: UIScrollView
    private let qrContentView: UIImageView
    private let explanationLabel: UILabel
    private let shareLinkButton: UIButton

    private let proxyUrlString: String

    var verticalCenterConstraint: NSLayoutConstraint?
    var contentTopAnchor: NSLayoutConstraint?
    var contentBottomAnchor: NSLayoutConstraint?

    init(dcContext: DcContext, proxyUrlString: String) {
        self.dcContext = dcContext
        self.proxyUrlString = proxyUrlString

        qrContentView = UIImageView()
        qrContentView.contentMode = .scaleAspectFit
        qrContentView.translatesAutoresizingMaskIntoConstraints = false

        shareLinkButton = UIButton(type: .system)
        shareLinkButton.setTitle(String.localized("proxy_share_link"), for: .normal)
        shareLinkButton.translatesAutoresizingMaskIntoConstraints = false

        explanationLabel = UILabel()
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        explanationLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        explanationLabel.text = String.localized("proxy_share_explain")

        contentStackView = UIStackView(arrangedSubviews: [qrContentView, explanationLabel, shareLinkButton, UIView()])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.spacing = 16

        contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStackView)

        super.init(nibName: nil, bundle: nil)

        if #available(iOS 13, *) {
            view.backgroundColor = .secondarySystemBackground
        } else {
            view.backgroundColor = DcColors.defaultBackgroundColor
        }

        shareLinkButton.addTarget(self, action: #selector(ShareProxyViewController.shareInviteLink(_:)), for: .touchUpInside)
        shareLinkButton.setTitleColor(DcColors.primary, for: .normal)

        let svg = dcContext.createQRSVG(for: proxyUrlString)
        qrContentView.image = getQrImage(svg: svg)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: String.localized("done"), style: .done, target: self, action: #selector(ShareProxyViewController.done(_:)))

        view.addSubview(contentScrollView)

        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError() }

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
        guard let inviteLinkURL = URL(string: proxyUrlString) else { return }

        Utils.share(url: inviteLinkURL, parentViewController: self, sourceView: sender)
    }

    @objc private func done(_ sender: Any) {
        dismiss(animated: true)
    }
}
