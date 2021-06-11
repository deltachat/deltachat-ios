import UIKit
import DcCore

class WelcomeViewController: UIViewController, ProgressAlertHandler {
    private let dcContext: DcContext
    var progressObserver: NSObjectProtocol?
    var onProgressSuccess: VoidFunction?

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private lazy var welcomeView: WelcomeContentView = {
        let view = WelcomeContentView()
        view.onLogin = { [weak self] in
            guard let self = self else { return }
            let accountSetupController = AccountSetupController(dcContext: self.dcContext, editView: false)
            accountSetupController.onLoginSuccess = {
                [weak self] in
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.appCoordinator.presentTabBarController()
                    appDelegate.appCoordinator.popTabsToRootViewControllers()
                }
            }
            self.navigationController?.pushViewController(accountSetupController, animated: true)
        }
        view.onScanQRCode  = { [weak self] in
            guard let self = self else { return }
            let qrReader = QrCodeReaderController()
            qrReader.delegate = self
            self.qrCodeReader = qrReader
            self.navigationController?.pushViewController(qrReader, animated: true)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var qrCodeReader: QrCodeReaderController?
    weak var progressAlert: UIAlertController?

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        self.navigationItem.title = String.localized("welcome_desktop")
        onProgressSuccess = { [weak self] in
            let profileInfoController = ProfileInfoViewController(context: dcContext)
            profileInfoController.onClose = {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.appCoordinator.presentTabBarController()
                }
            }
            self?.navigationController?.setViewControllers([profileInfoController], animated: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        welcomeView.minContainerHeight = view.frame.height - view.safeAreaInsets.top
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        welcomeView.minContainerHeight = size.height - view.safeAreaInsets.top
        scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        let nc = NotificationCenter.default
        if let observer = self.progressObserver {
            nc.removeObserver(observer)
            self.progressObserver = nil
        }
    }

    // MARK: - setup
    private func setupSubviews() {

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(welcomeView)

        let frameGuide = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide

        frameGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        frameGuide.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        frameGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        frameGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        contentGuide.leadingAnchor.constraint(equalTo: welcomeView.leadingAnchor).isActive = true
        contentGuide.topAnchor.constraint(equalTo: welcomeView.topAnchor).isActive = true
        contentGuide.trailingAnchor.constraint(equalTo: welcomeView.trailingAnchor).isActive = true
        contentGuide.bottomAnchor.constraint(equalTo: welcomeView.bottomAnchor).isActive = true

        // this enables vertical scrolling
        frameGuide.widthAnchor.constraint(equalTo: contentGuide.widthAnchor).isActive = true
    }

    // MARK: - actions

    private func createAccountFromQRCode(qrCode: String) {
        let success = dcContext.setConfigFromQR(qrCode: qrCode)
        if success {
            addProgressAlertListener(dcContext: dcContext, progressName: dcNotificationConfigureProgress, onSuccess: handleLoginSuccess)
            showProgressAlert(title: String.localized("login_header"), dcContext: dcContext)
            dcContext.stopIo()
            dcContext.configure()
        } else {
            accountCreationErrorAlert()
        }
    }

    private func handleLoginSuccess() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            appDelegate.registerForNotifications()
        }
        onProgressSuccess?()
    }

    private func accountCreationErrorAlert() {
        let title = dcContext.lastErrorString ?? String.localized("error")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default))
        present(alert, animated: true)
    }
}

extension WelcomeViewController: QrCodeReaderDelegate {
    func handleQrCode(_ code: String) {
        let lot = dcContext.checkQR(qrCode: code)
        if let domain = lot.text1, lot.state == DC_QR_ACCOUNT {
            confirmAccountCreationAlert(accountDomain: domain, qrCode: code)
        } else {
            qrErrorAlert()
        }
    }

    private func confirmAccountCreationAlert(accountDomain domain: String, qrCode: String) {
        let title = String.localizedStringWithFormat(String.localized("qraccount_ask_create_and_login"), domain)
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        let okAction = UIAlertAction(
            title: String.localized("ok"),
            style: .default,
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.dismissQRReader()
                self.createAccountFromQRCode(qrCode: qrCode)
            }
        )

        let qrCancelAction = UIAlertAction(
            title: String.localized("cancel"),
            style: .cancel,
            handler: { [weak self] _ in
                self?.dismissQRReader()
            }
        )

        alert.addAction(okAction)
        alert.addAction(qrCancelAction)
        qrCodeReader?.present(alert, animated: true)
    }

    private func qrErrorAlert() {
        let title = String.localized("qraccount_qr_code_cannot_be_used")
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(
            title: String.localized("ok"),
            style: .default,
            handler: { [weak self] _ in
                self?.qrCodeReader?.startSession()
            }
        )
        alert.addAction(okAction)
        qrCodeReader?.present(alert, animated: true, completion: nil)
    }

    private func dismissQRReader() {
        self.navigationController?.popViewController(animated: true)
        self.qrCodeReader = nil
    }
}

// MARK: - WelcomeContentView
class WelcomeContentView: UIView {

    var onLogin: VoidFunction?
    var onScanQRCode: VoidFunction?
    var onImportBackup: VoidFunction?

    var minContainerHeight: CGFloat = 0 {
        didSet {
            containerMinHeightConstraint.constant = minContainerHeight
            logoHeightConstraint.constant = calculateLogoHeight()
        }
    }

    private lazy var containerMinHeightConstraint: NSLayoutConstraint = {
        return container.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    }()

    private lazy var logoHeightConstraint: NSLayoutConstraint = {
        return logoView.heightAnchor.constraint(equalToConstant: 0)
    }()

    private var container = UIView()

    private var logoView: UIImageView = {
        let image = #imageLiteral(resourceName: "dc_logo")
        let view = UIImageView(image: image)
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = String.localized("welcome_desktop")
        label.textColor = DcColors.grayTextColor
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = String.localized("welcome_intro1_message")
        label.font = UIFont.systemFont(ofSize: 22, weight: .regular)
        label.textColor = DcColors.grayTextColor
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private lazy var buttonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [loginButton, qrCodeButton /*, importBackupButton */])
        stack.axis = .vertical
        stack.spacing = 15
        return stack
    }()

    private lazy var loginButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        let title = String.localized("login_header").uppercased()
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DcColors.primary
        let insets = button.contentEdgeInsets
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(loginButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var qrCodeButton: UIButton = {
        let button = UIButton()
        let title = String.localized("qrscan_title")
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(qrCodeButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private lazy var importBackupButton: UIButton = {
        let button = UIButton()
        let title = String.localized("import_backup_title")
        button.setTitleColor(UIColor.systemBlue, for: .normal)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(importBackupButtonPressed(_:)), for: .touchUpInside)
        return button
    }()

    private let defaultSpacing: CGFloat = 20

    init() {
        super.init(frame: .zero)
        setupSubviews()
        backgroundColor = DcColors.defaultBackgroundColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - setup
    private func setupSubviews() {
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        container.topAnchor.constraint(equalTo: topAnchor).isActive = true
        container.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        container.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.75).isActive = true
        container.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0).isActive = true

        containerMinHeightConstraint.isActive = true

        _ = [logoView, titleLabel, subtitleLabel].map {
            addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let bottomLayoutGuide = UILayoutGuide()
        container.addLayoutGuide(bottomLayoutGuide)
        bottomLayoutGuide.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        bottomLayoutGuide.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.55).isActive = true

        subtitleLabel.topAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor).isActive = true
        subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        subtitleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
        titleLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -defaultSpacing).isActive = true
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        logoView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -defaultSpacing).isActive = true
        logoView.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        logoHeightConstraint.constant = calculateLogoHeight()
        logoHeightConstraint.isActive = true
        logoView.widthAnchor.constraint(equalTo: logoView.heightAnchor).isActive = true

        let logoTopAnchor = logoView.topAnchor.constraint(equalTo: container.topAnchor, constant: 20)   // this will allow the container to grow in height
        logoTopAnchor.priority = .defaultLow
        logoTopAnchor.isActive = true

        let buttonContainerGuide = UILayoutGuide()
        container.addLayoutGuide(buttonContainerGuide)
        buttonContainerGuide.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor).isActive = true
        buttonContainerGuide.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true

        loginButton.setContentHuggingPriority(.defaultHigh, for: .vertical)

        container.addSubview(buttonStack)
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.centerXAnchor.constraint(equalTo: container.centerXAnchor).isActive = true
        buttonStack.centerYAnchor.constraint(equalTo: buttonContainerGuide.centerYAnchor).isActive = true

        let buttonStackTopAnchor = buttonStack.topAnchor.constraint(equalTo: buttonContainerGuide.topAnchor, constant: defaultSpacing)
        // this will allow the container to grow in height
        let buttonStackBottomAnchor = buttonStack.bottomAnchor.constraint(equalTo: buttonContainerGuide.bottomAnchor, constant: -50)

        _ = [buttonStackTopAnchor, buttonStackBottomAnchor].map {
            $0.priority = .defaultLow
            $0.isActive = true
        }
    }

    private func calculateLogoHeight() -> CGFloat {
        let titleHeight = titleLabel.intrinsicContentSize.height
        let subtitleHeight = subtitleLabel.intrinsicContentSize.height
        let intrinsicHeight = subtitleHeight + titleHeight
        let maxHeight: CGFloat = 100
        return intrinsicHeight > maxHeight ? maxHeight : intrinsicHeight
    }

    // MARK: - actions
     @objc private func loginButtonPressed(_ sender: UIButton) {
         onLogin?()
     }

     @objc private func qrCodeButtonPressed(_ sender: UIButton) {
         onScanQRCode?()
     }

     @objc private func importBackupButtonPressed(_ sender: UIButton) {
         onImportBackup?()
     }
}
