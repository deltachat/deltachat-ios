import UIKit
import WebKit
import DcCore

class FullMessageViewController: WebViewViewController {

    var loadButton: UIBarButtonItem {
        let button = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.refresh, target: self, action: #selector(showLoadOptions))
        button.accessibilityLabel = String.localized("load_remote_content")
        button.tintColor = DcColors.primary
        return button
    }

    var messageId: Int
    private var loadContentOnce = false

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
    

    init(dcContext: DcContext, messageId: Int) {
        self.messageId = messageId
        super.init(dcContext: dcContext)
        self.allowSearch = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        var title = dcContext.getMessage(id: messageId).subject
        if title.isEmpty {
            title = String.localized("chat_input_placeholder")
        }
        self.title = title

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
        let checkmark = "✔︎ "
        var onceCheckmark = ""
        var neverCheckmark = ""
        var alwaysCheckmark = ""
        if loadContentOnce {
            onceCheckmark = checkmark
        } else if UserDefaults.standard.bool(forKey: "html_load_remote_content") {
            alwaysCheckmark = checkmark
        } else {
            neverCheckmark = checkmark
        }

        let alert = UIAlertController(title: String.localized("load_remote_content"),
                                      message: String.localized("load_remote_content_ask"),
                                      preferredStyle: .safeActionSheet)
        let alwaysAction = UIAlertAction(title: "\(alwaysCheckmark)\(String.localized("always"))", style: .default, handler: alwaysActionPressed(_:))
        let neverAction = UIAlertAction(title: "\(neverCheckmark)\(String.localized("never"))", style: .default, handler: neverActionPressed(_:))
        let onceAction = UIAlertAction(title: "\(onceCheckmark)\(String.localized("once"))", style: .default, handler: onceActionPressed(_:))


        alert.addAction(onceAction)
        alert.addAction(alwaysAction)
        alert.addAction(neverAction)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func alwaysActionPressed(_ action: UIAlertAction) {
        UserDefaults.standard.set(true, forKey: "html_load_remote_content")
        UserDefaults.standard.synchronize()
        loadContentOnce = false
        loadUnrestricedHtml()
    }

    @objc func onceActionPressed(_ action: UIAlertAction) {
        UserDefaults.standard.set(false, forKey: "html_load_remote_content")
        UserDefaults.standard.synchronize()
        loadContentOnce = true
        loadUnrestricedHtml()
    }

    @objc func neverActionPressed(_ action: UIAlertAction) {
        UserDefaults.standard.set(false, forKey: "html_load_remote_content")
        UserDefaults.standard.synchronize()
        loadContentOnce = false
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let html = self.dcContext.getMsgHtml(msgId: self.messageId)
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
