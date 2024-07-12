import UIKit
import DcCore
import Network

class ConnectivityViewController: WebViewViewController {

    private var connectivityMonitor: AnyObject?
    private var isLowDataMode: Bool = false

    override init(dcContext: DcContext) {
        super.init(dcContext: dcContext)

        // set connectivity changed observer before we actually init html,
        // otherwise, we may miss events and the html is not correct.
        NotificationCenter.default.addObserver(self, selector: #selector(ConnectivityViewController.handleConnectivityChanged(_:)), name: .connectivityChanged, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ConnectivityViewController.handleLowerPowerModeChanged(_:)),
                                               name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                                               object: nil
        )
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
                guard let self else { return }
                self.isLowDataMode = path.isConstrained
                self.loadHtml()
            }
            isLowDataMode = monitor.currentPath.isConstrained
            monitor.start(queue: DispatchQueue.global())
            self.connectivityMonitor = monitor
        }
    }
    
    // called everytime the view will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHtml()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if #available(iOS 13.0, *) {
            (connectivityMonitor as? NWPathMonitor)?.cancel()
        }
    }

    // this method needs to be run from a background thread
    private func getNotificationStatus(backgroundRefreshStatus: UIBackgroundRefreshStatus) -> String {
        let connectiviy = self.dcContext.getConnectivity()
        let pushState = dcContext.getPushState()
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

        if pushState == DC_PUSH_NOT_CONNECTED || connectiviy == DC_CONNECTIVITY_NOT_CONNECTED {
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

        if pushState == DC_PUSH_CONNECTED {
            return "<span class=\"green dot\"></span>"
                .appending(title)
                .appending(String.localized("connectivity_connected"))
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
                       String.localized(stringID: "notifications_avg_hours", parameter: Int(averageDelta / 3600)) :
                       String.localized(stringID: "notifications_avg_minutes", parameter: Int(averageDelta / 60)))
    }


    @objc private func handleLowerPowerModeChanged(_ notification: Notification) {
        loadHtml()
    }

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        loadHtml()
    }

    private func loadHtml() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // `UIApplication.shared` needs to be called from main thread
            let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus

            // do the remaining things in background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
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

                let notificationStatus = self.getNotificationStatus(backgroundRefreshStatus: backgroundRefreshStatus)
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
