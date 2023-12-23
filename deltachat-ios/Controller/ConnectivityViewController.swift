import UIKit
import DcCore
import Network

class ConnectivityViewController: WebViewViewController {
    private var connectivityChangedObserver: NSObjectProtocol?
    private var lowPowerModeObserver: NSObjectProtocol?
    private var connectivityMonitor: AnyObject?
    private var isLowDataMode: Bool = false

    // called only once after loading
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("connectivity")
        self.webView.scrollView.bounces = false
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        view.backgroundColor = DcColors.defaultBackgroundColor

        if #available(iOS 13.0, *) {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                guard let self = self else { return }
                self.isLowDataMode = path.isConstrained
                self.loadHtml()
            }
            isLowDataMode = monitor.currentPath.isConstrained
            monitor.start(queue: DispatchQueue.global(qos: .background))
            self.connectivityMonitor = monitor
        }
    }

    // called everytime the view will appear
    override func viewWillAppear(_ animated: Bool) {
        // set connectivity changed observer before we acutally init html,
        // otherwise, we may miss events and the html is not correct.
        connectivityChangedObserver = NotificationCenter.default.addObserver(forName: eventConnectivityChanged,
                                                     object: nil,
                                                     queue: nil) { [weak self] _ in
                                                        self?.loadHtml()
                                                     }
        lowPowerModeObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                                                                      object: nil,
                                                                      queue: nil) { [weak self] _ in
                                                                         self?.loadHtml()
                                                                      }
        loadHtml()
    }

    override func viewWillDisappear(_ animated: Bool) {
        if let connectivityChangedObserver = self.connectivityChangedObserver {
            NotificationCenter.default.removeObserver(connectivityChangedObserver)
        }

        if let lowPowerModeObserver = self.lowPowerModeObserver {
            NotificationCenter.default.removeObserver(lowPowerModeObserver)
        }

        if #available(iOS 13.0, *) {
            (connectivityMonitor as? NWPathMonitor)?.cancel()
        }
    }

    // this method needs to be run from a background thread
    private func getNotificationStatus(hasNotifyToken: Bool, backgroundRefreshStatus: UIBackgroundRefreshStatus) -> String {
        let connectiviy = self.dcContext.getConnectivity()
        let title = " <b>" + String.localized("pref_notifications") + ":</b> "
        let notificationsEnabledInDC = !UserDefaults.standard.bool(forKey: "notifications_disabled")
        var notificationsEnabledInSystem = false
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            NotificationManager.notificationEnabledInSystem { enabled in
                notificationsEnabledInSystem = enabled
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 1) == .timedOut {
            return "<span class=\"red dot\"></span>"
                .appending(title)
                .appending("Timeout Error")
        }

        if dcContext.isAnyDatabaseEncrypted() {
            return "<span class=\"red dot\"></span>"
                .appending(title)
                .appending("Unreliable due to \"Encrypted Accounts\" experiment, see \"Device Messages\" for fixing")
        }

        if !notificationsEnabledInDC {
            return "<span class=\"disabled dot\"></span>"
                .appending(title)
                .appending(String.localized("disabled_in_dc"))
        }

        if !notificationsEnabledInSystem {
            return "<span class=\"disabled dot\"></span>"
                .appending(title)
                .appending(String.localized("disabled_in_system_settings"))
        }

        if backgroundRefreshStatus != .available {
            return "<span class=\"disabled dot\"></span>"
                .appending(title)
                .appending(String.localized("bg_app_refresh_disabled"))
        }

        if !hasNotifyToken || connectiviy == DC_CONNECTIVITY_NOT_CONNECTED {
            return "<span class=\"red dot\"></span>"
                .appending(title)
                .appending(String.localized("connectivity_not_connected"))
        }

        if isLowDataMode {
            return "<span class=\"disabled dot\"></span>"
                .appending(title)
                .appending(String.localized("connectivity_low_data_mode"))
        }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return "<span class=\"disabled dot\"></span>"
                .appending(title)
                .appending(String.localized("connectivity_low_power_mode"))
        }

        let timestamps = UserDefaults.standard.array(forKey: Constants.Keys.notificationTimestamps) as? [Double]
        guard let timestamps = timestamps, !timestamps.isEmpty else {
            // in most cases, here the app was just installed and we do not have any data.
            // so, do not show something error-like here.
            // (in case of errors, it usually converts to an error sooner or later)
            return "<span class=\"yellow dot\"></span>"
                .appending(title)
                .appending(String.localized("connectivity_connected"))
        }

        let averageDelta = (Double(Date().timeIntervalSince1970) - timestamps.first!) / Double(timestamps.count)

        var lastWakeups = ""
        var lastWakeupsCnt = 0
        for timestamp in timestamps.reversed() {
            lastWakeups += (lastWakeupsCnt > 0 ? ", " : "") + DateUtils.getExtendedAbsTimeSpanString(timeStamp: timestamp)
            lastWakeupsCnt += 1
            if lastWakeupsCnt >= 3 {
                break
            }
        }

        return  "<span class=\"yellow dot\"></span>"
            .appending(title)
            .appending(String.localizedStringWithFormat(String.localized("last_check_at"), lastWakeups))
            .appending(", ")
            .appending(averageDelta / 3600 > 2 ?
                       String.localized(stringID: "notifications_avg_hours", count: Int(averageDelta / 3600)) :
                       String.localized(stringID: "notifications_avg_minutes", count: Int(averageDelta / 60)))
    }

    private func loadHtml() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // `UIApplication.shared` needs to be called from main thread
            var hasNotifyToken = false
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                hasNotifyToken = appDelegate.notifyToken != nil
            }
            let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus

            // do the remaining things in background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                var html = self.dcContext.getConnectivityHtml()
                    .replacingOccurrences(of: "</style>", with:
                        """
                        body {
                            font-size: 13pt;
                            font-family: -apple-system, sans-serif;
                            padding: 0 .5rem .5rem .5rem;
                            -webkit-text-size-adjust: none;
                        }

                        .disabled {
                            background-color: #aaaaaa;
                        }

                        @media (prefers-color-scheme: dark) {
                          body {
                            background-color: black !important;
                            color: #eee;
                          }
                        }
                        </style>
                        """)

                let notificationStatus = self.getNotificationStatus(hasNotifyToken: hasNotifyToken, backgroundRefreshStatus: backgroundRefreshStatus)
                if let range = html.range(of: "</ul>") {
                    html = html.replacingCharacters(in: range, with: "<li>" + notificationStatus + "</li></ul>")
                }

                DispatchQueue.main.async {
                    self.webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }
    }
}
