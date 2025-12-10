import Foundation
import UIKit
import DcCore
import SDWebImageSVGKitPlugin

class BackupTransferViewController: UIViewController {

    public enum TranferState {
        case unknown
        case error
        case success
    }

    private let dcContext: DcContext
    private let dcAccounts: DcAccounts
    private var dcBackupProvider: DcBackupProvider?
    private var imexObserver: NSObjectProtocol?
    private var transferState: TranferState = TranferState.unknown
    private var warnAboutCopiedQrCodeOnAbort = false
    private var isFinishing = false

    private var cancelButton: UIBarButtonItem {
        return UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
    }

    private let statusLine: UILabel
    private let qrContentView: UIImageView
    private let contentStackView: UIStackView
    private let contentScrollView: UIScrollView

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let progress = UIActivityIndicatorView(style: .medium)
        progress.style = .large
        progress.translatesAutoresizingMaskIntoConstraints = false
        return progress
    }()

    init(dcAccounts: DcAccounts) {
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()

        statusLine = UILabel()
        statusLine.translatesAutoresizingMaskIntoConstraints = false
        statusLine.text = String.localized("preparing_account")
        statusLine.textColor = DcColors.defaultTextColor
        statusLine.textAlignment = .center
        statusLine.numberOfLines = 0
        statusLine.lineBreakMode = .byWordWrapping
        statusLine.font = .preferredFont(forTextStyle: .body)

        qrContentView = UIImageView()
        qrContentView.contentMode = .scaleAspectFit
        qrContentView.translatesAutoresizingMaskIntoConstraints = false
        qrContentView.accessibilityHint = String.localized("qr_code")

        contentStackView = UIStackView(arrangedSubviews: [statusLine, qrContentView])
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.setCustomSpacing(10, after: statusLine)
        contentStackView.setCustomSpacing(10, after: qrContentView)
        contentStackView.axis = .vertical
        contentStackView.alignment = .center

        contentScrollView = UIScrollView()
        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.addSubview(contentStackView)

        super.init(nibName: nil, bundle: nil)

        view.addSubview(contentScrollView)
        view.addSubview(activityIndicator)
        view.backgroundColor = DcColors.defaultBackgroundColor

        setupSubviews()

        hidesBottomBarWhenPushed = true
        title = String.localized("multidevice_title")
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = cancelButton
        updateMenuItems()

        triggerLocalNetworkPrivacyAlert()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.dcAccounts.stopIo()
            self.dcBackupProvider = DcBackupProvider(self.dcContext)
            DispatchQueue.main.async {
                if !(self.dcBackupProvider?.isOk() ?? false) {
                    if self.transferState != TranferState.error {
                        self.transferState = TranferState.error
                        self.showLastErrorAlert("Cannot create backup provider")
                    }
                    return
                }
                let image = self.getQrImage(svg: self.dcBackupProvider?.getQrSvg())
                self.qrContentView.image = image
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                self.statusLine.textAlignment = .left
                self.statusLine.text = "➊ " + String.localized("multidevice_same_network_hint")
                                 + "\n\n➋ " + String.localized("multidevice_install_dc_on_other_device")
                                 + "\n\n➌ " + String.localized("multidevice_tap_scan_on_other_device")
                self.updateMenuItems()
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else { return }
                    self.dcBackupProvider?.wait()
                }
            }
        }
    }

    override func didMove(toParent parent: UIViewController?) {
        let isRemoved = parent == nil
        if isRemoved {
            isFinishing = true
            if let imexObserver = self.imexObserver {
                NotificationCenter.default.removeObserver(imexObserver)
            }
            if dcBackupProvider != nil {
                dcContext.stopOngoingProcess()
                dcBackupProvider?.unref()
                dcBackupProvider = nil
            }
            dcAccounts.startIo()
            UIApplication.shared.isIdleTimerDisabled = false
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            imexObserver = NotificationCenter.default.addObserver(forName: Event.importExportProgress, object: nil, queue: nil) { [weak self] notification in
                self?.handleImportExportProgress(notification)
            }
        }
    }

    // MARK: - Notifications

    @objc private func handleImportExportProgress(_ notification: Notification) {
        guard let ui = notification.userInfo, let permille = ui["progress"] as? Int, isFinishing == false else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            var statusLineText: String?
            var hideQrCode = false

            if permille == 0 {
                if self.transferState != TranferState.error {
                    self.transferState = TranferState.error
                    self.showLastErrorAlert("Error")
                }
                hideQrCode = true
            } else if permille < 1000 {
                let percent: Int = permille/10
                statusLineText = String.localized("transferring") + " \(percent)%"
                hideQrCode = true
            } else if permille == 1000 {
                self.transferState = TranferState.success
                self.navigationItem.leftBarButtonItem = nil // "Cancel" no longer fits as things are done
                statusLineText = String.localized("done") + " 😀"
                hideQrCode = true
            }

            if let statusLineText = statusLineText {
                self.statusLine.text = statusLineText
            }

            if hideQrCode && !self.qrContentView.isHidden {
                self.statusLine.textAlignment = .center
                self.qrContentView.isHidden = true
                updateMenuItems()
            }
        }
    }

    // MARK: - setup
    private func setupSubviews() {
        let qrDefaultWidth = qrContentView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.75)
        qrDefaultWidth.priority = UILayoutPriority(500)
        qrDefaultWidth.isActive = true
        let qrMinWidth = qrContentView.widthAnchor.constraint(lessThanOrEqualToConstant: 260)
        qrMinWidth.priority = UILayoutPriority(999)
        qrMinWidth.isActive = true

        let constraints = [
            qrContentView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.5),

            activityIndicator.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            activityIndicator.constraintHeightTo(100),
            activityIndicator.constraintWidthTo(100),

            contentScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentScrollView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentScrollView.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: contentScrollView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: contentScrollView.leadingAnchor, constant: 20),
            contentScrollView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: 20),
            contentScrollView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor, constant: 20),

            contentStackView.widthAnchor.constraint(equalTo: contentScrollView.widthAnchor, constant: -40),
        ]

        NSLayoutConstraint.activate(constraints)

        activityIndicator.isHidden = false
        activityIndicator.startAnimating()
    }
    
    private func getQrImage(svg: String?) -> UIImage? {
        guard let svg else { return nil }

        let svgData = svg.data(using: .utf8)
        return SDImageSVGKCoder.shared.decodedImage(with: svgData, options: [:])
    }

    private func showLastErrorAlert(_ errorContext: String) {
        var lastError = dcContext.lastErrorString
        if lastError.isEmpty {
            lastError = "<last error not set>"
        }
        let error = errorContext + " (" + lastError + ")"
        let alert = UIAlertController(title: String.localized("multidevice_title"), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    // MARK: - actions
    @objc private func cancelButtonPressed() {
        switch transferState {
        case .error, .success:
            self.navigationController?.popViewController(animated: true)
        case .unknown:
            let addInfo = warnAboutCopiedQrCodeOnAbort ? String.localized("multidevice_abort_will_invalidate_copied_qr") : nil
            let alert = UIAlertController(title: String.localized("multidevice_abort"), message: addInfo, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            navigationController?.present(alert, animated: true, completion: nil)
        }
    }

    private func updateMenuItems() {
        let menu = moreButtonMenu()
        let button =  UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
        navigationItem.rightBarButtonItem = button
    }

    private func moreButtonMenu() -> UIMenu {
        var actions = [UIMenuElement]()
        if !qrContentView.isHidden {
            actions.append(UIAction(title: String.localized("menu_copy_to_clipboard"), image: UIImage(systemName: "document.on.document")) { [weak self] _ in
                guard let self else { return }
                warnAboutCopiedQrCodeOnAbort = true
                UIPasteboard.general.string = dcBackupProvider?.getQr()
            })
        }
        actions.append(UIAction(title: String.localized("troubleshooting"), image: UIImage(systemName: "questionmark.circle")) { [weak self] _ in
            self?.openHelp(fragment: "#multiclient")
        })
        return UIMenu(children: actions)
    }
}


/// Does a best effort attempt to trigger the local network privacy alert.
///
/// It works by sending a UDP datagram to the discard service (port 9) of every
/// IP address associated with a broadcast-capable interface. This should
/// trigger the local network privacy alert, assuming the alert hasn’t already
/// been displayed for this app.
///
/// This code takes a ‘best effort’. It handles errors by ignoring them. As
/// such, there’s guarantee that it’ll actually trigger the alert.
///
/// - note: iOS devices don’t actually run the discard service. I’m using it
/// here because I need a port to send the UDP datagram to and port 9 is
/// always going to be safe (either the discard service is running, in which
/// case it will discard the datagram, or it’s not, in which case the TCP/IP
/// stack will discard it).
///
/// There should be a proper API for this (r. 69157424).
///
/// For more background on this, see [Triggering the Local Network Privacy Alert](https://developer.apple.com/forums/thread/663768).
func triggerLocalNetworkPrivacyAlert() {
    let sock4 = socket(AF_INET, SOCK_DGRAM, 0)
    guard sock4 >= 0 else { return }
    defer { close(sock4) }
    let sock6 = socket(AF_INET6, SOCK_DGRAM, 0)
    guard sock6 >= 0 else { return }
    defer { close(sock6) }

    let addresses = addressesOfDiscardServiceOnBroadcastCapableInterfaces()
    var message = [UInt8]("!".utf8)
    for address in addresses {
        address.withUnsafeBytes { buf in
            let sa = buf.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            let saLen = socklen_t(buf.count)
            let sock = sa.pointee.sa_family == AF_INET ? sock4 : sock6
            _ = sendto(sock, &message, message.count, MSG_DONTWAIT, sa, saLen)
        }
    }
}

/// Returns the addresses of the discard service (port 9) on every
/// broadcast-capable interface.
///
/// Each array entry is contains either a `sockaddr_in` or `sockaddr_in6`.
private func addressesOfDiscardServiceOnBroadcastCapableInterfaces() -> [Data] {
    var addrList: UnsafeMutablePointer<ifaddrs>?
    let err = getifaddrs(&addrList)
    guard err == 0, let start = addrList else { return [] }
    defer { freeifaddrs(start) }
    return sequence(first: start, next: { $0.pointee.ifa_next })
        .compactMap { i -> Data? in
            guard
                (i.pointee.ifa_flags & UInt32(bitPattern: IFF_BROADCAST)) != 0,
                let sa = i.pointee.ifa_addr
            else { return nil }
            var result = Data(UnsafeRawBufferPointer(start: sa, count: Int(sa.pointee.sa_len)))
            switch CInt(sa.pointee.sa_family) {
            case AF_INET:
                result.withUnsafeMutableBytes { buf in
                    let sin = buf.baseAddress!.assumingMemoryBound(to: sockaddr_in.self)
                    sin.pointee.sin_port = UInt16(9).bigEndian
                }
            case AF_INET6:
                result.withUnsafeMutableBytes { buf in
                    let sin6 = buf.baseAddress!.assumingMemoryBound(to: sockaddr_in6.self)
                    sin6.pointee.sin6_port = UInt16(9).bigEndian
                }
            default:
                return nil
            }
            return result
        }
}
