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
        self.title = String.localized("menu_help")
        setupSubviews()
        loadHtmlContent()
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

    private func loadHtmlContent() {
        let lang = "de"

        if let url = Bundle.main.url(forResource: "de_help", withExtension: "html", subdirectory: "Assets/Help")  {
            safe_fatalError("Failed to load resource from bundle")
            return
        }


        if let url = Bundle.main.url(forResource: "de_help", withExtension: "html", subdirectory: "Help")  {
            safe_fatalError("Failed to load resource from bundle")
            return
        }

        if let url = Bundle.main.path(forResource: "de_help", ofType: "html")  {
            safe_fatalError("Failed to load resource from bundle")
            return
        }

        guard let url = Bundle.main.url(forResource: "de_help", withExtension: "html", subdirectory: "Assets/Help/de")  else {
                        safe_fatalError("Failed to load resource from bundle")
                        return
                    }

        webView.loadFileURL(url, allowingReadAccessTo: url)
        let request = URLRequest(url: url)
        webView.load(request)

    }


}
