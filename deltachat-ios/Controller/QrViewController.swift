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
        let qrCode = dcContext.getSecurejoinQr(chatId: 0)
        let view = QrViewContentView(contact: contact, qrCode: qrCode)
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

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = String.localized("qr_code")
        setupSubviews()
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

    private var qrCodeView: QRCodeView = {
        let view = QRCodeView(frame: .zero)
        return view
    }()

    private var hintLabel: UILabel = {
        let label = UILabel.init()
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
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

    init(contact: DcContact?, qrCode: String?) {
        super.init(frame: .zero)
        if let contact = contact {
            hintLabel.text = String.localizedStringWithFormat(
                String.localized("qrshow_join_contact_hint"),
                contact.email
            )
        }
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
