import UIKit
import WebKit
import DcCore

class FullMessageViewController: WebViewViewController {

    var loadButton: UIBarButtonItem {
        // to not encourages people to get used to tap the load button
        // just to see whether the message they get will change, this is a very generic icon.
        // (best would be if we know before if an HTML message contains images and thelike,
        // but we don't and this is probably also not worth  the effort. so we used the second best approach :)
        let image = UIImage(systemName: "ellipsis.circle")

        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(showLoadOptions))
        button.accessibilityLabel = String.localized("load_remote_content")
        return button
    }

    var messageId: Int
    private var isContactRequest: Bool
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
    

    init(dcContext: DcContext, messageId: Int, isContactRequest: Bool) {
        self.messageId = messageId
        self.isContactRequest = isContactRequest
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
        if !isContactRequest && UserDefaults.standard.bool(forKey: "html_load_remote_content") {
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
        } else if !isContactRequest && UserDefaults.standard.bool(forKey: "html_load_remote_content") {
            alwaysCheckmark = checkmark
        } else {
            neverCheckmark = checkmark
        }

        let alert = UIAlertController(title: String.localized("load_remote_content"),
                                      message: String.localized("load_remote_content_ask"),
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: "\(neverCheckmark)\(String.localized(isContactRequest ? "no" : "never"))", style: .default, handler: neverActionPressed(_:)))
        alert.addAction(UIAlertAction(title: "\(onceCheckmark)\(String.localized("once"))", style: .default, handler: onceActionPressed(_:)))
        if !isContactRequest {
            alert.addAction(UIAlertAction(title: "\(alwaysCheckmark)\(String.localized("always"))", style: .default, handler: alwaysActionPressed(_:)))
        }

        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    @objc func alwaysActionPressed(_ action: UIAlertAction) {
        UserDefaults.standard.set(true, forKey: "html_load_remote_content")
        loadContentOnce = false
        loadUnrestricedHtml()
    }

    @objc func onceActionPressed(_ action: UIAlertAction) {
        if !isContactRequest {
            UserDefaults.standard.set(false, forKey: "html_load_remote_content")
        }
        loadContentOnce = true
        loadUnrestricedHtml()
    }

    @objc func neverActionPressed(_ action: UIAlertAction) {
        if !isContactRequest {
            UserDefaults.standard.set(false, forKey: "html_load_remote_content")
        }
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
            guard let self else { return }
            let html = self.dcContext.getMsgHtml(msgId: self.messageId)
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
