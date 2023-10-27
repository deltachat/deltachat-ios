import UIKit
import WebKit
import DcCore

class FullMessageViewController: WebViewViewController {

    var loadButton: UIBarButtonItem {
        let image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "ellipsis.circle")
        } else {
            image = UIImage(named: "ic_more")
        }
        let button = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(showLoadOptions))
        button.accessibilityLabel = String.localized("load_remote_content")
        return button
    }

    var messageId: Int
    private var isHalfBlocked: Bool
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
    

    init(dcContext: DcContext, messageId: Int, isHalfBlocked: Bool) {
        self.messageId = messageId
        self.isHalfBlocked = isHalfBlocked
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
        if !isHalfBlocked && UserDefaults.standard.bool(forKey: "html_load_remote_content") {
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
        } else if !isHalfBlocked && UserDefaults.standard.bool(forKey: "html_load_remote_content") {
            alwaysCheckmark = checkmark
        } else {
            neverCheckmark = checkmark
        }

        let alert = UIAlertController(title: String.localized("load_remote_content"),
                                      message: String.localized("load_remote_content_ask"),
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: "\(neverCheckmark)\(String.localized(isHalfBlocked ? "no" : "never"))", style: .default, handler: neverActionPressed(_:)))
        alert.addAction(UIAlertAction(title: "\(onceCheckmark)\(String.localized("once"))", style: .default, handler: onceActionPressed(_:)))
        if !isHalfBlocked {
            alert.addAction(UIAlertAction(title: "\(alwaysCheckmark)\(String.localized("always"))", style: .default, handler: alwaysActionPressed(_:)))
        }

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
        if !isHalfBlocked {
            UserDefaults.standard.set(false, forKey: "html_load_remote_content")
            UserDefaults.standard.synchronize()
        }
        loadContentOnce = true
        loadUnrestricedHtml()
    }

    @objc func neverActionPressed(_ action: UIAlertAction) {
        if !isHalfBlocked {
            UserDefaults.standard.set(false, forKey: "html_load_remote_content")
            UserDefaults.standard.synchronize()
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
            guard let self = self else { return }
            let html = self.dcContext.getMsgHtml(msgId: self.messageId)
            DispatchQueue.main.async {
                self.webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
}
