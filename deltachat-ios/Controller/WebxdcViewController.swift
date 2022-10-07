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
    var webxdcName: String = ""
    var sourceCodeUrl: String?

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
        self.shortcutManager = ShortcutManager(dcContext: dcContext, messageId: messageId)
        super.init()
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
            // remove observer
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
        // TODO: what about tel://
        if let url = navigationAction.request.url {
            if url.scheme == "mailto" {
                askToChatWith(url: url)
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

    private func askToChatWith(url: URL) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let emailAddress = parseEmailAddress(from: url) else {
            return
        }

        let alert = UIAlertController(title: String.localizedStringWithFormat(String.localized("ask_start_chat_with"), emailAddress),
                                      message: nil,
                                      preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("start_chat"), style: .default, handler: { _ in
            RelayHelper.shared.askToChatWithMailto = false
            _ = appDelegate.application(UIApplication.shared, open: url)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func parseEmailAddress(from url: URL) -> String? {
        if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
           !urlComponents.path.isEmpty {
             return RelayHelper.shared.splitString(urlComponents.path)[0]
        }
        return nil
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

        default:
            logger.debug("another method was called")
        }
    }
}

extension WebxdcViewController: WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, let scheme = url.scheme, scheme == INTERNALSCHEMA {
            if url.path == "/webxdc-update.json" || url.path == "webxdc-update.json" {
                let lastKnownSerial = Int(url.query ?? "0") ?? 0
                let data = Data(
                    dcContext.getWebxdcStatusUpdates(msgId: messageId, lastKnownSerial: lastKnownSerial).utf8)
                let response = URLResponse(url: url, mimeType: "application/json", expectedContentLength: data.count, textEncodingName: "utf-8")
                
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
                return
            }

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
