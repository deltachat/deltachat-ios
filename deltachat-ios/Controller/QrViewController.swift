import Foundation
import UIKit
import DcCore

class QrViewController: UIViewController {

    private let dcContext: DcContext

    var onDismissed: (() -> Void)?

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var qrContentView: QrViewContentView = {
        let qrCode = dcContext.getSecurejoinQr(chatId: chatId)
        let view = QrViewContentView(qrCode: qrCode, hint: qrCodeHint)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    var qrCodeHint: String {
        willSet {
            qrContentView.hintText = newValue
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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        qrContentView.minContainerHeight = view.frame.height - (view.safeAreaInsets.top + view.safeAreaInsets.bottom)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        qrContentView.minContainerHeight = size.height - (view.safeAreaInsets.top + view.safeAreaInsets.bottom)
        scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        onDismissed?()
    }

    // MARK: - setup
    private func setupSubviews() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(qrContentView)

        let frameGuide = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide

        frameGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        frameGuide.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        frameGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        frameGuide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true

        contentGuide.leadingAnchor.constraint(equalTo: qrContentView.leadingAnchor).isActive = true
        contentGuide.topAnchor.constraint(equalTo: qrContentView.topAnchor).isActive = true
        contentGuide.trailingAnchor.constraint(equalTo: qrContentView.trailingAnchor).isActive = true
        contentGuide.bottomAnchor.constraint(equalTo: qrContentView.bottomAnchor).isActive = true

        // this enables vertical scrolling
        frameGuide.widthAnchor.constraint(equalTo: contentGuide.widthAnchor).isActive = true
    }

}

// MARK: - QrViewContentView
class QrViewContentView: UIView {

    var hintText: String? {
        willSet {
            hintLabel.text = newValue
        }
    }

    private var qrCodeView: QRCodeView = {
        let view = QRCodeView(frame: .zero)
        return view
    }()

    private lazy var hintLabel: UILabel = {
        let label = UILabel.init()
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.text = hintText
        return label
    }()

    private let container = UIView()

    var minContainerHeight: CGFloat = 0 {
        didSet {
            containerMinHeightConstraint.constant = minContainerHeight
        }
    }

    private lazy var containerMinHeightConstraint: NSLayoutConstraint = {
        return container.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    }()

    init(qrCode: String?, hint: String) {
        super.init(frame: .zero)
        hintText = hint
        if let qrCode = qrCode {
            qrCodeView.generateCode(
                qrCode,
                foregroundColor: .darkText,
                backgroundColor: .white
            )
        }
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.topAnchor.constraint(equalTo: topAnchor).isActive = true
        container.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        container.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.75).isActive = true
        container.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0).isActive = true

        containerMinHeightConstraint.isActive = true

        let stackView = UIStackView(arrangedSubviews: [qrCodeView, hintLabel])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor).isActive = true

        qrCodeView.translatesAutoresizingMaskIntoConstraints = false
        let qrCodeMinWidth = stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        qrCodeMinWidth.priority = UILayoutPriority(rawValue: 1000)
        qrCodeMinWidth.isActive = true
        let qrCodeDefaultWidth = stackView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 1)
        qrCodeDefaultWidth.priority = UILayoutPriority(500)
        qrCodeDefaultWidth.isActive = true
        qrCodeView.heightAnchor.constraint(equalTo: qrCodeView.widthAnchor, multiplier: 1).isActive = true

        hintLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        let stackTopAnchor = stackView.topAnchor.constraint(equalTo: container.layoutMarginsGuide.topAnchor)
        stackTopAnchor.priority = .defaultLow
        stackTopAnchor.isActive = true

        let stackBottomAnchor = stackView.bottomAnchor.constraint(equalTo: container.layoutMarginsGuide.bottomAnchor)
        stackBottomAnchor.priority = .defaultLow
        stackBottomAnchor.isActive = true
    }
}
