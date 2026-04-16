import UIKit
import DcCore
import Network

class ConnectivityViewController: WebViewViewController {

    private lazy var moreButton: UIBarButtonItem = {
        let image = UIImage(systemName: "ellipsis.circle")
        return UIBarButtonItem(image: image, menu: moreButtonMenu())
    }()

    override init(dcContext: DcContext) {
        super.init(dcContext: dcContext)

        // set connectivity changed observer before we actually init html,
        // otherwise, we may miss events and the html is not correct.
        NotificationCenter.default.addObserver(self, selector: #selector(ConnectivityViewController.handleConnectivityChanged(_:)), name: Event.connectivityChanged, object: nil)
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
        navigationItem.rightBarButtonItems = [moreButton]
    }
    
    // called everytime the view will appear
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHtml()
    }

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        guard dcContext.id == notification.userInfo?["account_id"] as? Int else { return }

        loadHtml()
    }

    private func moreButtonMenu() -> UIMenu {
        let clearImage = if #available(iOS 16.0, *) { "eraser" } else { "rectangle.portrait" }
        let actions = [
            UIAction(title: String.localized("clear_all_relay_storage"), image: UIImage(systemName: clearImage)) { [weak self] _ in
                guard let self else { return }
                dcContext.clearAllRelayStorage()
                loadHtml()
            },
        ]
        return UIMenu(children: actions)
    }

    private func loadHtml() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let html = dcContext.getConnectivityHtml()
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

            DispatchQueue.main.async { [weak self] in
                self?.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
