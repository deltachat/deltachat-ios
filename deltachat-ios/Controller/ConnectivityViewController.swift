import UIKit
import DcCore
import Network

class ConnectivityViewController: WebViewViewController {

    private var connectivityMonitor: NWPathMonitor?

    override init(dcContext: DcContext) {
        super.init(dcContext: dcContext)

        // set connectivity changed observer before we actually init html,
        // otherwise, we may miss events and the html is not correct.
        NotificationCenter.default.addObserver(self, selector: #selector(ConnectivityViewController.handleConnectivityChanged(_:)), name: Event.connectivityChanged, object: nil)
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

        let connectivityMonitor = NWPathMonitor()
        connectivityMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.loadHtml()
        }
        connectivityMonitor.start(queue: DispatchQueue.global())
        self.connectivityMonitor = connectivityMonitor
    }
    
    // called everytime the view will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHtml()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        connectivityMonitor?.cancel()
    }

    // this method needs to be run from a background thread. returns (color, informationalText) with:
    // red:      network disconnected
    // yellow:   other things that worse notifications
    // green:    everything on purpose
    // disabled: notifications disabled in Delta - if they're disabled in system, this is "yellow"
    static func getNotificationStatus(dcContext: DcContext, backgroundRefreshStatus: UIBackgroundRefreshStatus) -> (String, String) {
        let connectiviy = dcContext.getConnectivity()
        let pushState = dcContext.getPushState()
        var notificationsEnabledInSystem = false
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            NotificationManager.notificationEnabledInSystem { enabled in
                notificationsEnabledInSystem = enabled
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 1) == .timedOut {
            return ("yellow", "Timeout Error. Notifications might be disabled in system settings")
        }

        if dcContext.isAnyDatabaseEncrypted() {
            return ("yellow", "Unreliable due to \"Encrypted Accounts\" experiment, see \"Device Messages\" for fixing")
        }

        if dcContext.isMuted() {
            return ("disabled", String.localized("disabled_in_dc"))
        }

        if !notificationsEnabledInSystem {
            return ("yellow", String.localized("disabled_in_system_settings"))
        }

        if backgroundRefreshStatus != .available {
            return ("yellow", String.localized("bg_app_refresh_disabled"))
        }

        if connectiviy == DC_CONNECTIVITY_NOT_CONNECTED {
            return ("red", String.localized("connectivity_not_connected"))
        }

        if pushState == DC_PUSH_NOT_CONNECTED {
            return ("red", "Push not connected")
        }

        let isLowDataMode = NWPathMonitor().currentPath.isConstrained
        if isLowDataMode {
            return ("yellow", String.localized("connectivity_low_data_mode"))
        }

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return ("yellow", String.localized("connectivity_low_power_mode"))
        }

        if pushState == DC_PUSH_CONNECTED {
            return ("green", String.localized("connectivity_connected"))
        }

        let timestamps = UserDefaults.standard.array(forKey: Constants.Keys.notificationTimestamps) as? [Double]
        guard let timestamps = timestamps, !timestamps.isEmpty else {
            // in most cases, here the app was just installed and we do not have any data.
            // so, do not show something error-like here.
            // (in case of errors, it usually converts to an error sooner or later)
            return ("yellow", String.localized("connectivity_connected"))
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

        return ("yellow",
            String.localizedStringWithFormat(String.localized("last_check_at"), lastWakeups)
                .appending(", ")
                .appending(averageDelta / 3600 > 2 ?
                    String.localized(stringID: "notifications_avg_hours", parameter: Int(averageDelta / 3600)) :
                    String.localized(stringID: "notifications_avg_minutes", parameter: Int(averageDelta / 60)))
            )
    }


    @objc private func handleLowerPowerModeChanged(_ notification: Notification) {
        loadHtml()
    }

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        guard dcContext.id == notification.userInfo?["account_id"] as? Int else { return }

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

                let (color, notificationStatus) = ConnectivityViewController.getNotificationStatus(dcContext: dcContext, backgroundRefreshStatus: backgroundRefreshStatus)
                if let range = html.range(of: "</ul>") {
                    let title = String.localized("pref_notifications")
                    html = html.replacingCharacters(in: range, with: "<li><span class=\"\(color) dot\"></span> <b>\(title)</b>: \(notificationStatus)</li></ul>")
                }

                DispatchQueue.main.async {
                    self.webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }
    }
}
