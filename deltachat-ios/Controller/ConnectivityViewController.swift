import UIKit
import DcCore

class ConnectivityViewController: WebViewViewController {
    private let dcContext: DcContext
    private var connectivityChangedObserver: NSObjectProtocol?

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // called only once after loading
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("connectivity")
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        view.backgroundColor = DcColors.defaultBackgroundColor
    }

    // called everytime the view will appear
    override func viewWillAppear(_ animated: Bool) {
        // set connectivity changed observer before we acutally init html,
        // otherwise, we may miss events and the html is not correct.
        connectivityChangedObserver = NotificationCenter.default.addObserver(forName: dcNotificationConnectivityChanged,
                                                     object: nil,
                                                     queue: nil) { [weak self] _ in
                                                        self?.loadHtml()
                                                     }
        loadHtml()
    }

    override func viewDidDisappear(_ animated: Bool) {
        if let connectivityChangedObserver = self.connectivityChangedObserver {
            NotificationCenter.default.removeObserver(connectivityChangedObserver)
        }
    }

    // this method needs to be run from a background thread
    private func getNotificationStatus() -> String {
        let timestamps = UserDefaults.standard.array(forKey: Constants.Keys.notificationTimestamps) as? [Double]
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
            return String.localized("no_data")
        }

        if !notificationsEnabledInDC {
            return """
                      <span class="yellow dot"></span>
                   """.appending(" ").appending(String.localized("notifications_disabled_dc"))
        }

        if !notificationsEnabledInSystem {
            return """
                      <span class="yellow dot"></span>
                   """.appending(" ").appending(String.localized("notifications_disabled"))
        }

        guard let timestamps = timestamps else {
            return String.localized("no_data")
        }

        if timestamps.isEmpty || timestamps.count == 1 {
            return """
                      <span class="red dot"></span>
                   """.appending(" ").appending(String.localized("notifications_not_working"))
        }

        var timestampDeltas: Double = 0
        for (index, element) in timestamps.enumerated() where index > 0 {
            let diff = element - timestamps[index - 1]
            timestampDeltas += diff
        }

        let averageDelta = timestampDeltas / Double(timestamps.count - 1)
        let lastWakeup = DateUtils.getExtendedRelativeTimeSpanString(timeStamp: timestamps.last!)

        if averageDelta / Double(60 * 60) > 1 {
            // more than 1 hour in average
            return  """
                        <span class="green dot"></span>
                    """
                .appending(" ")
                .appending(String.localizedStringWithFormat(String.localized("notifications_stats_hours"),
                                                            "\(Int(averageDelta / 60 * 60))", lastWakeup))
        }

        return  """
                    <span class="green dot"></span>
                """
            .appending(" ")
            .appending(String.localizedStringWithFormat(String.localized("notifications_stats_minutes"),
                                                        "\(Int(averageDelta / 60))", lastWakeup))
    }

    private func loadHtml() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let html = self.dcContext.getConnectivityHtml()
                .replacingOccurrences(of: "</style>", with:
                    """
                    body {
                        font-size: 13pt;
                        font-family: -apple-system, sans-serif;
                        padding: 0 .5rem .5rem .5rem;
                        -webkit-text-size-adjust: none;
                    }

                    @media (prefers-color-scheme: dark) {
                      body {
                        background-color: black !important;
                        color: #eee;
                      }
                    }
                    </style>
                    """).replacingOccurrences(of: "</body>", with:
                    """
                    <h3>\(String.localized("pref_notifications"))</h3>
                    <ul><li>\(self.getNotificationStatus())</li>
                    </body>
                    """)
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
