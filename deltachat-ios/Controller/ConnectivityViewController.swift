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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("connectivity")
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        view.backgroundColor = DcColors.defaultBackgroundColor
        loadHtml()
    }

    override func viewDidAppear(_ animated: Bool) {
        connectivityChangedObserver = NotificationCenter.default.addObserver(forName: dcNotificationConnectivityChanged,
                                                     object: nil,
                                                     queue: nil) { [weak self] _ in
                                                        self?.loadHtml()
                                                     }
    }

    override func viewDidDisappear(_ animated: Bool) {
        if let connectivityChangedObserver = self.connectivityChangedObserver {
            NotificationCenter.default.removeObserver(connectivityChangedObserver)
        }
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
                    """)
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
