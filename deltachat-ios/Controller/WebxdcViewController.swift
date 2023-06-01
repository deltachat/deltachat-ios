import UIKit
import WebKit
import DcCore

class WebxdcViewController: WebViewViewController {
    
    enum WebxdcHandler: String {
        case log  = "log"
        case setUpdateListener = "setUpdateListener"
        case sendStatusUpdate = "sendStatusUpdateHandler"
        case sendToChat = "sendToChat"
    }
    let INTERNALSCHEMA = "webxdc"
    
    var messageId: Int
    var webxdcUpdateObserver: NSObjectProtocol?
    var webxdcName: String = ""
    var sourceCodeUrl: String?
    private var allowInternet: Bool = false

    private var shortcutManager: ShortcutManager?

    private lazy var moreButton: UIBarButtonItem = {
        let image: UIImage?
        if #available(iOS 13.0, *) {
            image = UIImage(systemName: "ellipsis.circle")
        } else {
            image = UIImage(named: "ic_more")
        }
        return UIBarButtonItem(image: image,
                               style: .plain,
                               target: self,
                               action: #selector(moreButtonPressed))
    }()
    
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
        let addr = dcContext.addr?
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        let displayname = (dcContext.displayname ?? dcContext.addr)?
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        
        let script = """
        window.webxdc = (() => {
          var log = (s)=>webkit.messageHandlers.log.postMessage(s);
        
          var update_listener = () => {};

          let should_run_again = false;
          let running = false;
          let lastSerial = 0;
          window.__webxdcUpdate = async () => {
            if (running) {
                should_run_again = true
                return
            }
            should_run_again = false
            running = true;
            try {
                const updates = await fetch("webxdc-update.json?"+lastSerial).then((response) => response.json())
                updates.forEach((update) => {
                  update_listener(update);
                  if (lastSerial < update["max_serial"]){
                    lastSerial = update["max_serial"]
                  }
                });
            } catch (e) {
                log("json error: "+ e.message)
            } finally {
                running = false;
                if (should_run_again) {
                    await window.__webxdcUpdate()
                }
            }
          }

          return {
            selfAddr: decodeURI("\((addr ?? "unknown"))"),
        
            selfName: decodeURI("\((displayname ?? "unknown"))"),
        
            setUpdateListener: (cb, serial) => {
                update_listener = cb
                return window.__webxdcUpdate()
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

            sendToChat: async (message) => {
                const data = {};
                if (!message.text && !message.file) {
                    return Promise.reject("Invalid empty message, at least one of text or file should be provided");
                }
                if (message.text) {
                    data.text = message.text;
                }
                if (message.file) {
                    if (!message.file.name || typeof message.file.base64 !== 'string') {
                        return Promise.reject("provided file is invalid, you need to set both name and base64 content");
                    }
                    data.base64 = message.file.base64;
                    data.name = message.file.name;
                }
                webkit.messageHandlers.sendToChat.postMessage(data);
            }
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
        contentController.add(self, name: WebxdcHandler.sendToChat.rawValue)
        
        let scriptSource = """
            window.RTCPeerConnection = ()=>{};
            RTCPeerConnection = ()=>{};
            try {
                window.webkitRTCPeerConnection = ()=>{};
                webkitRTCPeerConnection = ()=>{};
            } catch (e){}
            """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(script)

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
        self.messageId = messageId
        self.shortcutManager = ShortcutManager(dcContext: dcContext, messageId: messageId)
        super.init(dcContext: dcContext)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let msg = dcContext.getMessage(id: messageId)
        let dict = msg.getWebxdcInfoDict()

        let document = dict["document"] as? String ?? ""
        webxdcName = dict["name"] as? String ?? "ErrName" // name should not be empty
        let chatName = dcContext.getChat(chatId: msg.chatId).name
        self.allowInternet = dict["internet_access"] as? Bool ?? false

        self.title = document.isEmpty ? "\(webxdcName) – \(chatName)" : "\(document) – \(chatName)"
        navigationItem.rightBarButtonItem = moreButton

        if let sourceCode = dict["source_code_url"] as? String,
           !sourceCode.isEmpty {
            sourceCodeUrl = sourceCode
        }
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        let willBeRemoved = parent == nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = willBeRemoved
        if willBeRemoved {
            let nc = NotificationCenter.default
            if let webxdcUpdateObserver = webxdcUpdateObserver {
                nc.removeObserver(webxdcUpdateObserver)
            }
            shortcutManager = nil
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
        if let url = navigationAction.request.url {
            if url.scheme == "mailto" {
                openChatFor(url: url)
                decisionHandler(.cancel)
                return
            } else if url.scheme != INTERNALSCHEMA {
                logger.debug("cancel loading: \(url)")
                decisionHandler(.cancel)
                return
            }
        }
        logger.debug("loading: \(String(describing: navigationAction.request.url))")
        decisionHandler(.allow)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if allowInternet {
            loadHtml()
        } else {
            loadRestrictedHtml()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if #available(iOS 15.0, *) {
            webView.setAllMediaPlaybackSuspended(true)
        }
    }

    private func loadRestrictedHtml() {
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

    private func updateWebxdc() {
        webView.evaluateJavaScript("window.__webxdcUpdate()", completionHandler: nil)
    }

    @objc private func moreButtonPressed() {
        let alert = UIAlertController(title: webxdcName + " – " + String.localized("webxdc_app"),
                                      message: nil,
                                      preferredStyle: .safeActionSheet)
        let addToHomescreenAction = UIAlertAction(title: String.localized("add_to_home_screen"), style: .default, handler: addToHomeScreen(_:))
        alert.addAction(addToHomescreenAction)
        if sourceCodeUrl != nil {
            let sourceCodeAction = UIAlertAction(title: String.localized("source_code"), style: .default, handler: openUrl(_:))
            alert.addAction(sourceCodeAction)
        }
        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        self.present(alert, animated: true, completion: nil)
    }

    private func addToHomeScreen(_ action: UIAlertAction) {
        shortcutManager?.showShortcutLandingPage()
    }

    private func openUrl(_ action: UIAlertAction) {
        if let sourceCodeUrl = sourceCodeUrl,
           let url = URL(string: sourceCodeUrl) {
            UIApplication.shared.open(url)
        }
    }
}

extension WebxdcViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let handler = WebxdcHandler(rawValue: message.name)
        switch handler {
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

        case .sendToChat:
            logger.debug("send to chat: \(message.body)")
            // TODO: pass file and thext to share forward handler so that it results in a draft; exit the xdc

        default:
            logger.debug("another method was called")
        }
    }
}

extension WebxdcViewController: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, let scheme = url.scheme, scheme == INTERNALSCHEMA {
            let data: Data
            let mimeType: String
            let statusCode: Int
            if url.path == "/webxdc-update.json" || url.path == "webxdc-update.json" {
                let lastKnownSerial = Int(url.query ?? "0") ?? 0
                data = Data(
                    dcContext.getWebxdcStatusUpdates(msgId: messageId, lastKnownSerial: lastKnownSerial).utf8)
                mimeType = "application/json; charset=utf-8"
                statusCode = 200
            } else {
                let file = url.path
                let dcMsg = dcContext.getMessage(id: messageId)
                if url.lastPathComponent == "webxdc.js" {
                    data = Data(webxdcbridge.utf8)
                } else {
                    data = dcMsg.getWebxdcBlob(filename: file)
                }
                mimeType = DcUtils.getMimeTypeForPath(path: file)
                statusCode = (data.isEmpty ? 404 : 200)
            }

            var headerFields = [
                "Content-Type": mimeType,
                "Content-Length": "\(data.count)",
            ]

            if !self.allowInternet {
                headerFields["Content-Security-Policy"] = """
                    default-src 'self';
                    style-src 'self' 'unsafe-inline' blob: ;
                    font-src 'self' data: blob: ;
                    script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: ;
                    connect-src 'self' data: blob: ;
                    img-src 'self' data: blob: ;
                    webrtc 'block' ;
                    """
            }

            guard let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headerFields
            ) else {
                return
            }
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
