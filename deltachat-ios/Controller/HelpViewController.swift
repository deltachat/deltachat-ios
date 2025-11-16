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

    private lazy var doneButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
    }()

    private lazy var prevPageButton: UIBarButtonItem = {
        let image = UIImage(systemName: "chevron.left")
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(prevPageButtonPressed))
    }()

    private lazy var nextPageButton: UIBarButtonItem = {
        let image = UIImage(systemName: "chevron.right")
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(nextPageButtonPressed))
    }()

    private lazy var moreButton: UIBarButtonItem = {
        let image = UIImage(systemName: "ellipsis.circle")
        return UIBarButtonItem(image: image, menu: moreButtonMenu())
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = nil // mavigation bar is dense, and there is already a title in the page
        self.webView.isOpaque = false
        self.webView.backgroundColor = .clear
        view.backgroundColor = DcColors.defaultBackgroundColor
        navigationItem.leftBarButtonItem = doneButton
        navigationItem.rightBarButtonItems = [moreButton, nextPageButton, prevPageButton]
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

    @objc func doneButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc func prevPageButtonPressed() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            webView.evaluateJavaScript("window.scrollTo(0,0)")
        }
    }

    @objc func nextPageButtonPressed() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    private func moreButtonMenu() -> UIMenu {
        let actions = [
            UIAction(title: String.localized("delta_chat_homepage"), image: UIImage(systemName: "arrow.up.right")) { _ in
                if let url = URL(string: "https://delta.chat") {
                    UIApplication.shared.open(url)
                }
            },
            UIAction(title: String.localized("privacy_policy"), image: UIImage(systemName: "arrow.up.right")) { _ in
                if let url = URL(string: "https://delta.chat/gdpr") {
                    UIApplication.shared.open(url)
                }
            },
            UIAction(title: String.localized("contribute"), image: UIImage(systemName: "arrow.up.right")) { _ in
                if let url = URL(string: "https://delta.chat/contribute") {
                    UIApplication.shared.open(url)
                }
            },
            UIAction(title: String.localized("global_menu_help_report_desktop"), image: UIImage(systemName: "arrow.up.right")) { _ in
                if let url = URL(string: "https://github.com/deltachat/deltachat-ios/issues") {
                    UIApplication.shared.open(url)
                }
            },
        ]
        return UIMenu(children: actions)
    }
}

extension UIViewController {
    func openHelp(fragment: String? = nil) {
        self.navigationController?.pushViewController(HelpViewController(dcContext: DcAccounts.shared.getSelected(), fragment: fragment), animated: true)
    }
}
