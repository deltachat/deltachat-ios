import UIKit
import DcCore
import OSLog

public class LogViewController: UIViewController {

    private let dcContext: DcContext
    private let loadingIndicator = "\n\nLoading log ..."
    private var bottomConstraint: NSLayoutConstraint?

    private lazy var shareButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareButtonPressed))
        button.accessibilityLabel = String.localized("menu_share")
        button.isEnabled = false
        return button
    }()

    private lazy var logText: UITextView = {
        let textView = UITextView()
        textView.contentInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.keyboardDismissMode = .onDrag
        return textView
    }()

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        self.navigationItem.title = String.localized("pref_log_header")
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        view.addSubview(logText)
        view.backgroundColor = DcColors.defaultBackgroundColor

        let bottomConstraint = view.bottomAnchor.constraint(equalTo: logText.bottomAnchor)

        view.addConstraints([
            logText.constraintAlignTopToAnchor(view.safeAreaLayoutGuide.topAnchor),
            logText.constraintAlignLeadingToAnchor(view.safeAreaLayoutGuide.leadingAnchor),
            logText.constraintAlignTrailingToAnchor(view.safeAreaLayoutGuide.trailingAnchor),
            bottomConstraint
        ])
        self.bottomConstraint = bottomConstraint

        logText.text = getDebugVariables(dcContext: dcContext)
        logText.setContentOffset(.zero, animated: false)

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            let usageReport = dcContext.getStorageUsageReportString()
            let log = getLogLines()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let debugVariables = self.logText.text.replacingOccurrences(of: self.loadingIndicator, with: "")
                self.logText.text = debugVariables + "\n\n" + usageReport + "\n" + log
                self.shareButton.isEnabled = true
            }
        }

        navigationItem.rightBarButtonItem = shareButton

        NotificationCenter.default.addObserver(self, selector: #selector(LogViewController.keyboardDidShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LogViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc
    private func doneButtonPressed() {
        dismiss(animated: true)
    }

    public func getDebugVariables(dcContext: DcContext) -> String {
        var info = "**This log may contain sensitive information. If you want to post it publicly you may examine and edit it beforehand.**\n\n"

        let systemVersion = UIDevice.current.systemVersion
        info += "iosVersion=\(systemVersion)\n"

        info += "any-database-encrypted=\(dcContext.isAnyDatabaseEncrypted())\n"

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            info += "notify-token=\(appDelegate.notifyToken ?? "<unset>")\n"
        }

        var val = "?"
        switch UIApplication.shared.backgroundRefreshStatus {
        case .restricted: val = "restricted"
        case .available: val = "available"
        case .denied: val = "denied"
        @unknown default: assertionFailure("")
        }
        info += "backgroundRefreshStatus=\(val)\n"

        #if DEBUG
        info += "DEBUG=1\n"
        #else
        info += "DEBUG=0\n"
        #endif

        info += "\n" + dcContext.getInfo() + "\n"

        info += "notify-timestamps="
        if let timestamps = UserDefaults.standard.array(forKey: Constants.Keys.notificationTimestamps) as? [Double] {
            for currTimestamp in timestamps {
                info += DateUtils.getExtendedAbsTimeSpanString(timeStamp: currTimestamp) + " "
            }
        }
        info += "\n"

        info += UserDefaults.debugArrayKey + "="
        if let infos = UserDefaults.shared?.array(forKey: UserDefaults.debugArrayKey)  as? [String] {
            var lastTime = ""
            for currInfo in infos {
                let currInfo = currInfo.split(separator: "|", maxSplits: 2)
                if let time = currInfo.first, let value = currInfo.last {
                    if time != lastTime {
                        info += "\n[" + time + "] "
                        lastTime = String(time)
                    }
                    info += value + " "
                }
            }
        }
        info += loadingIndicator

        return info
    }

    public func getLogLines() -> String {
        var log = ""

        if #available(iOS 15.0, *) {
            do {
                let store = try OSLogStore(scope: .currentProcessIdentifier)
                let position = store.position(timeIntervalSinceLatestBoot: 1)
                var entries: [String] = []
                entries = try store
                    .getEntries(at: position)
                    .compactMap { $0 as? OSLogEntryLog }
                    .filter { $0.subsystem == DcLogger.subsystem }
                    .map { "[\($0.date.formatted())] \($0.composedMessage)" }
                if entries.isEmpty {
                    log += "\nEmpty log returned, maybe running in a Simulator."
                } else {
                    for entry in entries {
                        log += "\n" + entry
                    }
                }
            } catch {
                log += "\nCannot get log: \(error.localizedDescription)"
            }
        }

        log += "\n\nTo get the full log, use Console.app on a Mac."

        return log
    }

    // MARK: - actions

    @objc private func shareButtonPressed() {
        if let text = logText.text {
            Utils.share(text: text, parentViewController: self, sourceItem: shareButton)
        }
    }

    // MARK: - Notifications

    @objc func keyboardDidShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        bottomConstraint?.constant = keyboardFrame.height
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        bottomConstraint?.constant = 12
    }
}
