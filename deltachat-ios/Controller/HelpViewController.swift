import UIKit
import WebKit
import DcCore

class HelpViewController: WebViewViewController {

    let fragment: String?

    init(dcContext: DcContext, fragment: String? = nil) {
        self.fragment = fragment
        super.init(dcContext: dcContext)
        self.allowSearch = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var moreButton: UIBarButtonItem = {
        let image = UIImage(systemName: "ellipsis.circle")
        return UIBarButtonItem(image: image, menu: moreButtonMenu())
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("menu_help")
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        view.backgroundColor = DcColors.defaultBackgroundColor
        navigationItem.rightBarButtonItem = moreButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHtmlContent { [weak self] url in
            // return to main thread
            DispatchQueue.main.async {
                self?.webView.loadFileURL(url, allowingReadAccessTo: url)
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let fragment = self.fragment {
            let scrollToFragmentScript = "window.location.hash = '\(fragment)';"
            webView.evaluateJavaScript(scrollToFragmentScript, completionHandler: nil)
        }
    }

    private func loadHtmlContent(completionHandler: ((URL) -> Void)?) {
        // execute in background thread because file loading would blockui for a few milliseconds
        DispatchQueue.global(qos: .userInitiated).async {
            let langAndRegion = Locale.preferredLanguages.first ?? "en"
            let langOnly = String(langAndRegion.split(separator: "-").first ?? Substring("ErrLang"))
            var fileURL: URL?

            fileURL = Bundle.main.url(forResource: "help", withExtension: "html", subdirectory: "Assets/Help/\(langAndRegion)") ??
                Bundle.main.url(forResource: "help", withExtension: "html", subdirectory: "Assets/Help/\(langOnly)") ??
                Bundle.main.url(forResource: "help", withExtension: "html", subdirectory: "Assets/Help/en")

            guard let url = fileURL else {
                return assertionFailure("could not find help asset")
            }
            completionHandler?(url)
        }
    }

    private func moreButtonMenu() -> UIMenu {
        let actions = [
            UIAction(title: String.localized("delta_chat_homepage"), image: UIImage(systemName: "globe")) { _ in
                if let url = URL(string: "https://delta.chat") {
                    UIApplication.shared.open(url)
                }
            },
            UIAction(title: String.localized("privacy_policy"), image: UIImage(systemName: "hand.raised")) { _ in
                if let url = URL(string: "https://delta.chat/gdpr") {
                    UIApplication.shared.open(url)
                }
            },
            UIAction(title: String.localized("contribute"), image: UIImage(systemName: "wrench.and.screwdriver")) { _ in
                if let url = URL(string: "https://delta.chat/contribute") {
                    UIApplication.shared.open(url)
                }
            },
            UIAction(title: String.localized("global_menu_help_report_desktop"), image: UIImage(systemName: "ant")) { _ in
                if let url = URL(string: "https://github.com/deltachat/deltachat-ios/issues") {
                    UIApplication.shared.open(url)
                }
            },
        ]
        return UIMenu(children: actions)
    }
}
