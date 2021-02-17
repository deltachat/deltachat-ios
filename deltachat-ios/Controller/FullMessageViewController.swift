import UIKit
import WebKit
import DcCore

class FullMessageViewController: WebViewViewController {

    var loadButton: UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.refresh, target: self, action: #selector(showLoadOptions))
        button.tintColor = DcColors.primary
        return button
    }

    var message: DcMsg
    private var loadUrlAllowed = false

    // Block just everything :)
    let blockRules = """
    [
        {
            "trigger": {
                "url-filter": ".*"
            },
            "action": {
                "type": "block"
            }
        }
    ]
    """
    

    init(message: DcMsg) {
        self.message = message
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String.localized("chat_input_placeholder")
        self.navigationItem.rightBarButtonItem = loadButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UserDefaults.standard.bool(forKey: "html_load_remote_content") {
            loadHtml()
        } else {
            loadRestrictedHtml()
        }
    }

    @objc private func showLoadOptions() {
        let alert = UIAlertController(title: String.localized("load_remote_content"),
                                      message: String.localized("load_remote_content_ask"),
                                      preferredStyle: .safeActionSheet)
        let alwaysAction = UIAlertAction(title: String.localized("always"), style: .default, handler: alwaysActionPressed(_:))
        let neverAction = UIAlertAction(title: String.localized("never"), style: .default, handler: neverActionPressed(_:))
        let onceAction = UIAlertAction(title: String.localized("once"), style: .default, handler: onceActionPressed(_:))


        alert.addAction(onceAction)
        alert.addAction(alwaysAction)
        alert.addAction(neverAction)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func alwaysActionPressed(_ action: UIAlertAction) {
        UserDefaults.standard.set(true, forKey: "html_load_remote_content")
        UserDefaults.standard.synchronize()
        loadUnrestricedHtml()
    }

    @objc func onceActionPressed(_ action: UIAlertAction) {
        loadUnrestricedHtml()
    }

    @objc func neverActionPressed(_ action: UIAlertAction) {
        UserDefaults.standard.set(false, forKey: "html_load_remote_content")
        UserDefaults.standard.synchronize()
        loadRestrictedHtml()
    }

    private func loadUnrestricedHtml() {
        let configuration = self.webView.configuration
        configuration.userContentController.removeAllContentRuleLists()
        loadHtml()
    }

    private func loadRestrictedHtml() {
        WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "ContentBlockingRules",
                encodedContentRuleList: blockRules) { (contentRuleList, error) in

            guard let contentRuleList = contentRuleList, error == nil else {
                return
            }

            let configuration = self.webView.configuration
            configuration.userContentController.add(contentRuleList)
            self.loadHtml()
        }
    }

    private func loadHtml() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            let html = self.message.html
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
