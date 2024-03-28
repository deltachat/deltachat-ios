import UIKit
import DcCore
import OSLog

public class LogViewController: UIViewController {

    private let dcContext: DcContext
    private let loadingIndicator = "\n\nLoading log ..."

    private lazy var logText: UITextView = {
        let label = UITextView()
        label.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        self.view.addSubview(logText)
        self.view.backgroundColor = DcColors.defaultBackgroundColor
        self.view.addConstraints([
            logText.constraintAlignTopToAnchor(view.safeAreaLayoutGuide.topAnchor),
            logText.constraintAlignLeadingToAnchor(view.safeAreaLayoutGuide.leadingAnchor, paddingLeading: 12),
            logText.constraintAlignTrailingToAnchor(view.safeAreaLayoutGuide.trailingAnchor, paddingTrailing: 12),
            logText.constraintAlignBottomToAnchor(view.safeAreaLayoutGuide.bottomAnchor, paddingBottom: 12)
        ])

        logText.text = getDebugVariables(dcContext: dcContext)
        logText.setContentOffset(.zero, animated: false)

        DispatchQueue.global().async { [weak self] in
            if let log = self?.getLogLines() {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let debugVariables = self.logText.text.replacingOccurrences(of: self.loadingIndicator, with: "")
                    self.logText.text = debugVariables + "\n" + log
                }
            }
        }
    }

    @objc
    private func doneButtonPressed() {
        dismiss(animated: true)
    }

    public func getDebugVariables(dcContext: DcContext) -> String {
        var info = "**This log may contain sensitive information. If you want to post it publicly you may examine and edit it beforehand.**\n\n"

        let systemVersion = UIDevice.current.systemVersion
        info += "iosVersion=\(systemVersion)\n"

        let notifyEnabled = !UserDefaults.standard.bool(forKey: "notifications_disabled")
        info += "notify-enabled=\(notifyEnabled)\n"
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
}
