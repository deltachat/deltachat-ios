import UIKit
import WebKit

class WebViewViewController: UIViewController, WKNavigationDelegate {

    public lazy var webView: WKWebView = {
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        return view
    }()

    lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String.localized("search")
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.searchResultsUpdater = self
        searchController.searchBar.inputAccessoryView = acessoryViewContainer
        searchController.searchBar.autocorrectionType = .yes
        searchController.searchBar.keyboardType = .default
        return searchController
    }()

    lazy var acessoryViewContainer: InputBarAccessoryView = {
        let inputBar = InputBarAccessoryView()
        inputBar.setMiddleContentView(searchAccessoryBar, animated: false)
        inputBar.sendButton.isHidden = true
        return inputBar
    }()

    public lazy var searchAccessoryBar: ChatSearchAccessoryBar = {
        let view = ChatSearchAccessoryBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEnabled = false
        return view
    }()

    open var configuration: WKWebViewConfiguration {
        let preferences = WKPreferences()
        let config = WKWebViewConfiguration()
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = false
        } else {
            preferences.javaScriptEnabled = false
        }
        config.preferences = preferences
        return config
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
            url.host != nil,
            UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSubviews()
    }


    // MARK: - setup + configuration
    private func setupSubviews() {
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
        if #available(iOS 14.0, *) {
            navigationItem.searchController = searchController
        }
        acessoryViewContainer.setLeftStackViewWidthConstant(to: 0, animated: false)
        acessoryViewContainer.setRightStackViewWidthConstant(to: 0, animated: false)
        acessoryViewContainer.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
    }
}

extension WebViewViewController: UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
    }
}

extension WebViewViewController: ChatSearchDelegate {
    func onSearchPreviousPressed() {
    }

    func onSearchNextPressed() {
    }
}
