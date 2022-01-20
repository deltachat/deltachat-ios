
import UIKit
import WebKit
import DcCore

class WebxdcViewController: WebViewViewController {

    var messageId: Int
    var dcContext: DcContext
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
        self.dcContext = dcContext
        self.messageId = messageId
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = getTitleFromWebxdcInfoJson()

        let preferences = WKPreferences()
        let configuration = WKWebViewConfiguration()

        if #available(iOS 13.0, *) {
            preferences.isFraudulentWebsiteWarningEnabled = true
        }

        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            preferences.javaScriptEnabled = true
        }
        preferences.javaScriptCanOpenWindowsAutomatically = false

        configuration.preferences = preferences
    }

    private func getTitleFromWebxdcInfoJson() -> String {
        let jsonString = dcContext.getMessage(id: messageId).getWebxdcInfoJson()
        if let data: Data = jsonString.data(using: .utf8),
           let infoJson = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String:AnyObject],
           let title = infoJson["name"] as? String {
            return title
        }
        return ""
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadRestrictedHtml()
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
//            let html = self.dcContext.getMsgHtml(msgId: self.messageId)
//            DispatchQueue.main.async {
//                self.webView.loadHTMLString(html, baseURL: nil)
//            }
        }
    }
}
