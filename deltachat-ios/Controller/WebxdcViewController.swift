import UIKit
import WebKit
import DcCore

class WebxdcViewController: WebViewViewController {

    let INTERNALSCHEMA = "webxdc"
    let INTERNALDOMAIN = "local.app"

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

    override var configuration: WKWebViewConfiguration {
        let preferences = WKPreferences()
        let config = WKWebViewConfiguration()

        config.userContentController.add(self, name: "webxdcHandler")
        config.setURLSchemeHandler(self, forURLScheme: INTERNALSCHEMA)

        if #available(iOS 13.0, *) {
            preferences.isFraudulentWebsiteWarningEnabled = true
        }

        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            preferences.javaScriptEnabled = true
        }
        preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences = preferences
        preferences.javaScriptEnabled = false
        config.preferences = preferences
        return config
    }


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
            DispatchQueue.main.async {
                self.webView.load(URLRequest(url: URL(string: "\(self.INTERNALSCHEMA)://msg\(self.messageId).\(self.INTERNALDOMAIN)/index.html")!))
            }
        }
    }
}

extension WebxdcViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    }
}

extension WebxdcViewController: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, let scheme = url.scheme, scheme == INTERNALSCHEMA {
            let file = url.lastPathComponent
            logger.debug(file)
            let dcMsg = dcContext.getMessage(id: messageId)
            let data: Data = dcMsg.getWebxdcBlob(filename: file)
            let mimeType = DcUtils.getMimeTypeForPath(path: file)
            logger.debug(mimeType)

            if !mimeType.contains(subSequence: "text").isEmpty {
                logger.debug(String(bytes: data, encoding: String.Encoding.utf8) ?? "invalid string")
            }

            let response = URLResponse.init(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)

            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    }
}
