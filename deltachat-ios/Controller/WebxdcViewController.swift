import UIKit
import WebKit
import DcCore

class WebxdcViewController: WebViewViewController {
    
    enum WebxdcHandler: String {
        case log  = "log"
        case setUpdateListener = "setUpdateListener"
        case sendStatusUpdate = "sendStatusUpdateHandler"
    }
    let INTERNALSCHEMA = "webxdc"
    
    var messageId: Int
    var dcContext: DcContext
    var webxdcUpdateObserver: NSObjectProtocol?
    
    
    // Block just everything, except of webxdc urls
    let blockRules = """
    [
        {
            "trigger": {
                "url-filter": ".*"
            },
            "action": {
                "type": "block"
            }
        },
        {
            "trigger": {
                "url-filter": "webxdc://*"
            },
            "action": {
                "type": "ignore-previous-rules"
            }
        }
    ]
    """
    
    lazy var webxdcbridge: String = {
        let script = """
        window.webxdc = (() => {
          let setUpdateListenerPromise = null
          var log = (s)=>webkit.messageHandlers.log.postMessage(s);
        
          var update_listener = () => {};

          window.__webxdcUpdate = (updateString) => {
            try {
                var updates = JSON.parse(updateString);
                updates.forEach((update) => {
                  update_listener(update);
                });
            } catch (e) {
                log("json error: "+ e.message)
            } finally {
              if (setUpdateListenerPromise) {
                 setUpdateListenerPromise()
                 setUpdateListenerPromise = null
              }
            }
          }

          return {
            selfAddr: atob("\((dcContext.addr ?? "unknown").toBase64())"),
        
            selfName: atob("\((dcContext.displayname ?? dcContext.addr ?? "unknown").toBase64())"),
        
            setUpdateListener: (cb, serial) => {
                update_listener = cb
                const promise = new Promise((res, _rej) => {
                   setUpdateListenerPromise = res
                })
                webkit.messageHandlers.setUpdateListener.postMessage(typeof serial === "undefined" ? 0 : parseInt(serial));
                return promise
            },

            getAllUpdates: () => {
              console.error("deprecated 2022-02-20 all updates are returned through the callback set by setUpdateListener");
              return Promise.resolve([]);
            },
        
            sendUpdate: (payload, descr) => {
                // only one parameter is allowed, we we create a new parameter object here
                var parameter = {
                    payload: payload,
                    descr: descr
                };
                webkit.messageHandlers.sendStatusUpdateHandler.postMessage(parameter);
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
        contentController.add(self, name: WebxdcHandler.setUpdateListener.rawValue)
        contentController.add(self, name: WebxdcHandler.log.rawValue)
        
        config.userContentController = contentController
        config.setURLSchemeHandler(self, forURLScheme: INTERNALSCHEMA)
        
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true

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
        let msg = dcContext.getMessage(id: messageId)
        let chatName = dcContext.getChat(chatId: msg.chatId).name
        let webxdcName = msg.getWebxdcInfoDict()["name"] as? String ?? ""
        self.title = webxdcName + " – " + chatName
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            // remove observer
            let nc = NotificationCenter.default
            if let webxdcUpdateObserver = webxdcUpdateObserver {
                nc.removeObserver(webxdcUpdateObserver)
            }
        } else {
            addObserver()
        }
    }
    
    private func addObserver() {
        let nc = NotificationCenter.default
        webxdcUpdateObserver = nc.addObserver(
            forName: dcNotificationWebxdcUpdate,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let ui = notification.userInfo,
                  let messageId = ui["message_id"] as? Int else {
                      logger.error("failed to handle dcNotificationWebxdcUpdate")
                      return
                  }
            if messageId == self.messageId {
                self.updateWebxdc()
            }
        }
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadRestrictedHtml()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if #available(iOS 15.0, *) {
            webView.setAllMediaPlaybackSuspended(true)
        }
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
            let url = URL(string: "\(self.INTERNALSCHEMA)://acc\(self.dcContext.id)-msg\(self.messageId).localhost/index.html")
            let urlRequest = URLRequest(url: url!)
            DispatchQueue.main.async {
                self.webView.load(urlRequest)
            }
        }
    }

    var lastSerial: Int?
    private func updateWebxdc() {
        if let lastSerial = lastSerial {
            let statusUpdates = dcContext.getWebxdcStatusUpdates(msgId: messageId, lastKnownSerial: lastSerial)
            if let data: Data = statusUpdates.data(using: .utf8),
               let array = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [Any],
               let first = array.first as? [String: Any],
               let maxSerial = first["max_serial"] as? Int {
                self.lastSerial = maxSerial
            }
            webView.evaluateJavaScript("window.__webxdcUpdate(atob(\"\(statusUpdates.toBase64())\"))", completionHandler: nil)
        }
    }
}

extension WebxdcViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let handler = WebxdcHandler(rawValue: message.name)
        switch handler {
        case .setUpdateListener:
            guard let lastKnownSerial = message.body as? Int else {
                logger.error("could not convert param \(message.body) to int")
                return
            }
            lastSerial = lastKnownSerial
            updateWebxdc()
            
        case .log:
            guard let msg = message.body as? String else {
                logger.error("could not convert param \(message.body) to string")
                return
            }
            logger.debug("webxdc log msg: "+msg)
            
        case .sendStatusUpdate:
            guard let dict = message.body as? [String: AnyObject],
                  let payloadDict = dict["payload"] as?  [String: AnyObject],
                  let payloadJson = try? JSONSerialization.data(withJSONObject: payloadDict, options: []),
                  let payloadString = String(data: payloadJson, encoding: .utf8),
                  let description = dict["descr"] as? String else {
                      logger.error("Failed to parse status update parameters \(message.body)")
                      return
                  }
            _ = dcContext.sendWebxdcStatusUpdate(msgId: messageId, payload: payloadString, description: description)

        default:
            logger.debug("another method was called")
        }
    }
}

extension WebxdcViewController: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, let scheme = url.scheme, scheme == INTERNALSCHEMA {
            let file = url.path
            let dcMsg = dcContext.getMessage(id: messageId)
            var data: Data
            if url.lastPathComponent == "webxdc.js" {
                data = Data(webxdcbridge.utf8)
            } else {
                data = dcMsg.getWebxdcBlob(filename: file)
            }
            let mimeType = DcUtils.getMimeTypeForPath(path: file)
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
