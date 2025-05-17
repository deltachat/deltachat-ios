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
        qrContentView.setContentHuggingPriority(.defaultLow, for: .vertical)
        qrContentView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        shareLinkButton = UIButton(type: .system)
        shareLinkButton.setTitle(String.localized("proxy_share_link"), for: .normal)
        shareLinkButton.translatesAutoresizingMaskIntoConstraints = false

        explanationLabel = UILabel()
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false
        explanationLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        explanationLabel.text = String.localized("proxy_share_explain")
        explanationLabel.numberOfLines = 0
        explanationLabel.textAlignment = .center

        contentStackView = UIStackView(arrangedSubviews: [qrContentView, explanationLabel, shareLinkButton])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.spacing = 16

        contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStackView)

        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = .secondarySystemBackground

        shareLinkButton.addTarget(self, action: #selector(ShareProxyViewController.shareInviteLink(_:)), for: .touchUpInside)

        let svg = dcContext.createQRSVG(for: proxyUrlString)
        qrContentView.image = getQrImage(svg: svg)

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(ShareProxyViewController.done(_:)))

        view.addSubview(contentScrollView)

        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupConstraints() {
        verticalCenterConstraint = contentStackView.centerYAnchor.constraint(equalTo: contentScrollView.centerYAnchor)
        contentTopAnchor = contentStackView.topAnchor.constraint(equalTo: contentScrollView.topAnchor, constant: 16)
        contentBottomAnchor = contentScrollView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: 16)

        let constraints = [
            qrContentView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.65),
            qrContentView.widthAnchor.constraint(lessThanOrEqualToConstant: 260),
            qrContentView.heightAnchor.constraint(equalTo: qrContentView.widthAnchor),

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
        guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else { return }

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
