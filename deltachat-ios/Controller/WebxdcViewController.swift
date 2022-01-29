import UIKit
import WebKit
import DcCore

class WebxdcViewController: WebViewViewController {

    enum WebxdcHandler: String {
        case getStatusUpdates = "getStatusUpdatesHandler"
        case sendStatusUpdate = "sendStatusUpdateHandler"
    }
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

    lazy var webxdcbridge: String = {
        let script = """
        window.webxdc = (() => {
          var update_listener = () => {};

          // instead of calling .getStatusUpdatesHandler (-> async),
          // we're passing the updates directly to this js function
          window.__webxdcUpdateiOS = (updateString) => {
            var updates = JSON.parse(updateString);
            if (updates.length === 1) {
              update_listener(updates[0]);
            }
          };

          return {
            selfAddr: "\(dcContext.addr ?? "unknown")",

            selfName: "\(dcContext.displayname ?? "unknown")",

            setUpdateListener: (cb) => (update_listener = cb),

            getAllUpdates: () => {
              // FIXME: we need to add an callback here, comp. https://programming.vip/docs/the-perfect-solution-for-wkwebview-to-interact-with-js.html
              webkit.messageHandlers.getStatusUpdatesHandler.postMessage("0")
              // call to webkit.messageHandlers.getStatusUpdatesHandler.postMessage("0") doesn't return anything currently but showcases
              // the communication js -> swift is working
              return  Promise.resolve([]);
            },

            sendUpdate: (payload, descr) => {
                // only one parameter is allowed, we we create a new parameter object here
                var parameter = {
                    payload: payload,
                    descr: descr
                };
                webkit.messageHandlers.sendStatusUpdateHandler.postMessage(JSON.stringify(parameter));
            },
          };
        })();
        """
        return script
    }()

    override var configuration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        let contentController = WKUserContentController()

        contentController.add(self, name: WebxdcHandler.sendStatusUpdate.rawValue)
        contentController.add(self, name: WebxdcHandler.getStatusUpdates.rawValue)
        let bridgeScript = WKUserScript(source: webxdcbridge, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(bridgeScript)

        config.userContentController = contentController
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

    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // TODO: what about tel:// and mailto://
        if let url = navigationAction.request.url,
            url.scheme != INTERNALSCHEMA {
            logger.debug("cancel loading: \(url)")
            decisionHandler(.cancel)
            return
        }
        logger.debug("loading: \(String(describing: navigationAction.request.url))")
        decisionHandler(.allow)
    }

    private func getTitleFromWebxdcInfoJson() -> String {
        let jsonString = dcContext.getMessage(id: messageId).getWebxdcInfoJson()
        if let data: Data = jsonString.data(using: .utf8),
           let infoJson = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: AnyObject],
           let title = infoJson["name"] as? String {
            return title
        }
        return ""
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHtml()
    }


    private func loadRestrictedHtml() {
        // TODO: compile only once
        WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "WebxdcContentBlockingRules",
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
        let handler = WebxdcHandler(rawValue: message.name)
        switch handler {
        case .getStatusUpdates:
            logger.debug("getStatusUpdates called")
            guard let param = message.body as? String,
                    let statusId = Int(param) else {
                logger.error("could not convert param \(message.body) to int")
                return
            }
            let statusUpdates = dcContext.getWebxdcStatusUpdates(msgId: messageId, statusUpdateId: statusId)
            logger.debug("status updates for message \(messageId) and statusId: \(statusId): \(statusUpdates)")
            // TODO: return
        case .sendStatusUpdate:
            logger.debug("sendStatusUpdate called")
            // dcContext.sendWebxdcStatusUpdate(msgId: messageId, payload: <#T##String#>, description: <#T##String#>)
        default:
            logger.debug("another method was called")
        }
    }
}

extension WebxdcViewController: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, let scheme = url.scheme, scheme == INTERNALSCHEMA {
            let file = url.path
            logger.debug(file)
            let dcMsg = dcContext.getMessage(id: messageId)
            var data: Data
            if url.lastPathComponent == "webxdc.js" {
                data = Data(webxdcbridge.utf8)
            } else {
                data = dcMsg.getWebxdcBlob(filename: file)
            }
            let mimeType = DcUtils.getMimeTypeForPath(path: file)
            logger.debug(mimeType)

            if !mimeType.contains(subSequence: "text").isEmpty {
                logger.debug(String(bytes: data, encoding: String.Encoding.utf8) ?? "invalid string")
            }

            let response = URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: nil)

            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } else {
            logger.debug("not loading \(String(describing: urlSchemeTask.request.url))")
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    }
}
