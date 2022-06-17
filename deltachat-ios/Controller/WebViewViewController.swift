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
        searchController.searchBar.inputAccessoryView = accessoryViewContainer
        searchController.searchBar.autocorrectionType = .yes
        searchController.searchBar.keyboardType = .default
        return searchController
    }()

    lazy var accessoryViewContainer: InputBarAccessoryView = {
        let inputBar = InputBarAccessoryView()
        inputBar.setMiddleContentView(searchAccessoryBar, animated: false)
        inputBar.sendButton.isHidden = true
        inputBar.delegate = self
        return inputBar
    }()

    public lazy var searchAccessoryBar: ChatSearchAccessoryBar = {
        let view = ChatSearchAccessoryBar()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEnabled = false
        return view
    }()

    private lazy var keyboardManager: KeyboardManager? = {
        let manager = KeyboardManager()
        return manager
    }()


    private var debounceTimer: Timer?
    private var initializedSearch = false
    open var allowSearch = false

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
        keyboardManager?.bind(to: webView.scrollView)
        keyboardManager?.on(event: .didHide) { [weak self] _ in
            self?.webView.scrollView.contentInset.bottom = 0
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        keyboardManager = nil
    }

    // MARK: - setup + configuration
    private func setupSubviews() {
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0).isActive = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInset.bottom = 0

        if allowSearch, #available(iOS 14.0, *) {
            navigationItem.searchController = searchController
        }
        accessoryViewContainer.setLeftStackViewWidthConstant(to: 0, animated: false)
        accessoryViewContainer.setRightStackViewWidthConstant(to: 0, animated: false)
        accessoryViewContainer.padding = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
    }

    private func initSearch() {
        guard let path = Bundle.main.url(forResource: "search", withExtension: "js", subdirectory: "Assets") else {
            logger.error("internal search js not found")
            return
        }
        do {
            let data: Data = try Data(contentsOf: path)
            let jsCode: String = String(decoding: data, as: UTF8.self)
            // inject the search code
            webView.evaluateJavaScript(jsCode, completionHandler: { _, error in
                if let error = error {
                    logger.error(error)
                }
            })
        } catch {
            logger.error("could not load javascript: \(error)")
        }
    }

    private func find(text: String) {
        highlightAllOccurencesOf(string: text)
        updateAccessoryBar()
    }

    private func highlightAllOccurencesOf(string: String) {
        // search function
        let searchString = "WKWebView_HighlightAllOccurencesOfString('\(string)')"
        // perform search
        webView.evaluateJavaScript(searchString, completionHandler: { _, error in
            if let error = error {
                logger.error(error)
            }
        })
    }

    private func updateAccessoryBar() {
        handleSearchResultCount { [weak self] result in
            guard let self = self else { return }
            logger.debug("found \(result) elements")
            self.searchAccessoryBar.isEnabled = result > 0
            self.handleCurrentlySelected { [weak self] position in
                self?.searchAccessoryBar.updateSearchResult(sum: result, position: position == -1 ? 0 : position + 1)
            }
        }
    }

    private func handleSearchResultCount( completionHandler: @escaping (_ result: Int) -> Void) {
        getInt(key: "WKWebView_SearchResultCount", completionHandler: completionHandler)
    }

    private func handleCurrentlySelected( completionHandler: @escaping (_ result: Int) -> Void) {
        getInt(key: "WKWebView_CurrentlySelected", completionHandler: completionHandler)
    }

    private func getInt(key: String, completionHandler: @escaping (_ result: Int) -> Void) {
        webView.evaluateJavaScript(key) { (result, error) in
            if let error = error {
                logger.error(error)
            } else if result != nil,
               let integerResult = result as? Int {
                    completionHandler(integerResult)
            }
        }
    }

    private func removeAllHighlights() {
        webView.evaluateJavaScript("WKWebView_RemoveAllHighlights()", completionHandler: nil)
        updateAccessoryBar()
    }

    private func searchNext() {
        webView.evaluateJavaScript("WKWebView_SearchNext()", completionHandler: nil)
        updateAccessoryBar()
    }

    private func searchPrevious() {
        webView.evaluateJavaScript("WKWebView_SearchPrev()", completionHandler: nil)
        updateAccessoryBar()
    }
}

extension WebViewViewController: UISearchBarDelegate, UISearchControllerDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            logger.debug("search for \(searchText)")
            if searchText.isEmpty {
                self?.removeAllHighlights()
            } else {
                self?.find(text: searchText)
            }
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let text = searchController.searchBar.text ?? ""
        self.find(text: text)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.removeAllHighlights()
    }

    func willPresentSearchController(_ searchController: UISearchController) {
        if !initializedSearch {
            initializedSearch = true
            initSearch()
        }
    }
}

extension WebViewViewController: ChatSearchDelegate {
    func onSearchPreviousPressed() {
        logger.debug("onSearchPrevious pressed")
        self.searchPrevious()
    }

    func onSearchNextPressed() {
        logger.debug("onSearchNextPressed pressed")
        self.searchNext()
    }
}

extension WebViewViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didAdaptToKeyboard height: CGFloat) {
        logger.debug("didAdaptToKeyboard: \(height)")
        self.webView.scrollView.contentInset.bottom = height
    }
}
