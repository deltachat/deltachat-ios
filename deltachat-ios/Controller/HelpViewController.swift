import UIKit
import WebKit

class HelpViewController: UIViewController {

    private lazy var webView: WKWebView = {
        let view = WKWebView()
        return view
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        self.title = String.localized("menu_help")
        setupSubviews()
        loadHtmlContent { [unowned self] url in
            // return to main thread
            DispatchQueue.main.async {
                self.webView.loadFileURL(url, allowingReadAccessTo: url)
            }
        }
    }

    // MARK: - setup + configuration
    private func setupSubviews() {
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        if #available(iOS 11, *) {
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        } else {
            webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        }
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
    }

    private func loadHtmlContent(completionHandler: ((URL) -> Void)?) {
        // execute in background thread because file loading would blockui for a few milliseconds
        DispatchQueue.global(qos: .background).async {
            let lang = Utils.getDeviceLanguage() ?? "en" // en is backup
            var fileURL: URL?

            fileURL = Bundle.main.url(forResource: "help", withExtension: "html", subdirectory: "Assets/Help/\(lang)") ??
                Bundle.main.url(forResource: "en_help", withExtension: "html", subdirectory: "Assets/Help/en")

            guard let url = fileURL else {
                safe_fatalError("could not find help asset")
                return
            }
            completionHandler?(url)
        }
    }
}
