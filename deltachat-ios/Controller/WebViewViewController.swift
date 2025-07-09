import UIKit
@preconcurrency import WebKit
import DcCore

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
    var dcContext: DcContext

    open var configuration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()

        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.preferences = preferences
        return config
    }

    init(dcContext: DcContext) {
        self.dcContext = dcContext
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.scheme == "mailto" {
                openChatFor(url: url)
                decisionHandler(.cancel)
                return
            }
        }
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
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInset.bottom = 0

        if allowSearch {
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

        guard let data = try? Data(contentsOf: path),
              let jsCode = String(data: data, encoding: .utf8) else {
            logger.error("could not load javascript")
            return
        }
        // inject the search code
        webView.evaluateJavaScript(jsCode, completionHandler: { _, error in
            logger.error("\(String(describing: error))")
        })
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
            logger.error("\(String(describing: error))")
        })
    }

    private func updateAccessoryBar() {
        handleSearchResultCount { [weak self] result in
            guard let self else { return }
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
                logger.error("\(error)")
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

    func openChatFor(url: URL) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let emailAddress = parseEmailAddress(from: url) else {
            return
        }

        let contacts: [Int] = dcContext.getContacts(flags: DC_GCL_ADD_SELF, queryString: emailAddress)
        let index = contacts.firstIndex(where: { dcContext.getContact(id: $0).email == emailAddress }) ?? -1
        let contactId = index >= 0 ? contacts[index] : 0

        if contactId == 0 {
            let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), emailAddress),
                                          message: nil,
                                          preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
                _ = appDelegate.appCoordinator.handleMailtoURL(url, askToChat: false)
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            _ = appDelegate.appCoordinator.handleMailtoURL(url, askToChat: false)
        }
    }

    private func parseEmailAddress(from url: URL) -> String? {
        if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
           !urlComponents.path.isEmpty {
            return RelayHelper.shared.splitString(urlComponents.path).first
        }
        return nil
    }
}

extension WebViewViewController: UISearchBarDelegate, UISearchControllerDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
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
        self.searchPrevious()
    }

    func onSearchNextPressed() {
        self.searchNext()
    }
}

extension WebViewViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didAdaptToKeyboard height: CGFloat) {
        self.webView.scrollView.contentInset.bottom = height
    }
}
