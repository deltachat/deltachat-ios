import UIKit
import WebKit
import DcCore

class WebxdcViewController: WebViewViewController {
    
    enum WebxdcHandler: String {
        case log
        case sendStatusUpdate
        case sendToChat
        case sendRealtimeAdvertisement
        case sendRealtimeData
        case leaveRealtime
    }
    let INTERNALSCHEMA = "webxdc"
    
    var messageId: Int
    var msgChangedObserver: NSObjectProtocol?
    var msgReadDeliveredReactionFailedObserver: NSObjectProtocol?
    var webxdcUpdateObserver: NSObjectProtocol?
    var webxdcRealtimeDataObserver: NSObjectProtocol?
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
          let realtimeChannel = null;

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

          window.__webxdcRealtimeData = (intArray) => {
            if (realtimeChannel) {
              realtimeChannel.__receive(Uint8Array.from(intArray))
            }
          }

          const createRealtimeChannel = () => {
            let listener = null;
            return {
              setListener: (li) => listener = li,
              leave: () => webkit.messageHandlers.leaveRealtime.postMessage(""),
              send: (data) => {
                if ((!data) instanceof Uint8Array) {
                  throw new Error('realtime listener data must be a Uint8Array')
                }
                webkit.messageHandlers.sendRealtimeData.postMessage(Array.from(data));
              },
              __receive: (data) => {
                if (listener) {
                  listener(data);
                }
              },
            };
        }

          return {
            selfAddr: decodeURI("\((addr ?? "unknown"))"),
        
            selfName: decodeURI("\((displayname ?? "unknown"))"),
        
            joinRealtimeChannel: () => {
              realtimeChannel = createRealtimeChannel();
              webkit.messageHandlers.sendRealtimeAdvertisement.postMessage("");
              return realtimeChannel;
            },

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
                webkit.messageHandlers.sendStatusUpdate.postMessage(parameter);
            },

            sendToChat: async (message) => {
                const data = {};
                /** @type {(file: Blob) => Promise<string>} */
                const blobToBase64 = (file) => {
                    const dataStart = ";base64,";
                    return new Promise((resolve, reject) => {
                        const reader = new FileReader();
                        reader.readAsDataURL(file);
                        reader.onload = () => {
                            let data = reader.result;
                            resolve(data.slice(data.indexOf(dataStart) + dataStart.length));
                        };
                        reader.onerror = () => reject(reader.error);
                    });
                };

                if (!message.file && !message.text) {
                    return Promise.reject("sendToChat() error: file or text missing");
                }

                if (message.text) {
                    data.text = message.text;
                }

                if (message.file) {
                    if (!message.file.name) {
                        return Promise.reject("sendToChat() error: file name missing");
                    }
                    if (Object.keys(message.file).filter((key) => ["blob", "base64", "plainText"].includes(key)).length > 1) {
                        return Promise.reject("sendToChat() error: only one of blob, base64 or plainText allowed");
                    }

                    if (message.file.blob instanceof Blob) {
                        data.base64 = await blobToBase64(message.file.blob);
                    } else if (typeof message.file.base64 === "string") {
                        data.base64 = message.file.base64;
                    } else if (typeof message.file.plainText === "string") {
                        data.base64 = await blobToBase64(new Blob([message.file.plainText]));
                    } else {
                        return Promise.reject("sendToChat() error: none of blob, base64 or plainText set correctly");
                    }
                    data.name = message.file.name;
                }

                webkit.messageHandlers.sendToChat.postMessage(data);
            },

            importFiles: (filters) => {
                var element = document.createElement("input");
                element.type = "file";
                element.accept = [
                    ...(filters.extensions || []),
                    ...(filters.mimeTypes || []),
                ].join(",");
                element.multiple = filters.multiple || false;
                const promise = new Promise((resolve, _reject) => {
                    element.onchange = (_ev) => {
                        console.log("element.files", element.files);
                        const files = Array.from(element.files || []);
                        document.body.removeChild(element);
                        resolve(files);
                    };
                });
                element.style.display = "none";
                document.body.appendChild(element);
                element.click();
                console.log(element);
                return promise;
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
        contentController.add(self, name: WebxdcHandler.log.rawValue)
        contentController.add(self, name: WebxdcHandler.sendToChat.rawValue)
        contentController.add(self, name: WebxdcHandler.sendRealtimeAdvertisement.rawValue)
        contentController.add(self, name: WebxdcHandler.sendRealtimeData.rawValue)
        contentController.add(self, name: WebxdcHandler.leaveRealtime.rawValue)

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
    
    deinit {
        dcContext.leaveWebxdcRealtime(messageId: messageId)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = moreButton
        refreshWebxdcInfo()
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        let willBeRemoved = parent == nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = willBeRemoved
        if willBeRemoved {
            removeObservers()
        } else {
            addObservers()
        }
    }

    func refreshWebxdcInfo() {
        let msg = dcContext.getMessage(id: messageId)
        let dict = msg.getWebxdcInfoDict()

        let document = dict["document"] as? String ?? ""
        webxdcName = dict["name"] as? String ?? "ErrName" // name should not be empty
        let chatName = dcContext.getChat(chatId: msg.chatId).name
        self.allowInternet = dict["internet_access"] as? Bool ?? false

        self.title = document.isEmpty ? "\(webxdcName) – \(chatName)" : "\(document) – \(chatName)"
        if let sourceCode = dict["source_code_url"] as? String,
           !sourceCode.isEmpty {
            sourceCodeUrl = sourceCode
        }
    }

    private func addObservers() {
        let nc = NotificationCenter.default
        webxdcUpdateObserver = nc.addObserver(
            forName: eventWebxdcStatusUpdate,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self, let messageId = notification.userInfo?["message_id"] as? Int else { return }
            if messageId == self.messageId {
                self.updateWebxdc()
            }
        }

        webxdcRealtimeDataObserver = nc.addObserver(
            forName: eventWebxdcRealtimeData,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self, let userInfo = notification.userInfo, let messageId = userInfo["message_id"] as? Int else { return }
            if messageId == self.messageId, let data = userInfo["data"] as? Data {
                let byteArray = [UInt8](data)
                let commaSeparatedString = byteArray.map { String($0) }.joined(separator: ",")
                webView.evaluateJavaScript("window.__webxdcRealtimeData([" + commaSeparatedString + "])")
            }
        }

        msgChangedObserver = nc.addObserver(
            forName: .messagesChanged,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            self?.handleMessagesChanged(notification)
        }

        msgReadDeliveredReactionFailedObserver = nc.addObserver(
            forName: .messageReadDeliveredFailedReaction,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] notification in
            guard let self, let messageId = notification.userInfo?["message_id"] as? Int else { return }
            if messageId == self.messageId {
                self.refreshWebxdcInfo()
            }
        }

    }
    
    private func removeObservers() {
        let nc = NotificationCenter.default
        if let webxdcUpdateObserver = webxdcUpdateObserver {
            nc.removeObserver(webxdcUpdateObserver)
        }
        if let webxdcRealtimeDataObserver {
            nc.removeObserver(webxdcRealtimeDataObserver)
        }
        if let msgChangedObserver {
            nc.removeObserver(msgChangedObserver)
        }
        if let msgReadDeliveredReactionFailedObserver {
            nc.removeObserver(msgReadDeliveredReactionFailedObserver)
        }
        shortcutManager = nil
    }

    @objc private func handleMessagesChanged(_ notification: Notification) {
        guard let messageId = notification.userInfo?["message_id"] as? Int,
              messageId == self.messageId
        else { return }

        self.refreshWebxdcInfo()
    }

    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.scheme == "mailto" {
                openChatFor(url: url)
                decisionHandler(.cancel)
                return
            } else if url.scheme?.lowercased() == "openpgp4fpr" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            } else if url.scheme != INTERNALSCHEMA {
                decisionHandler(.cancel)
                return
            }
        }
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
            guard let self else { return }
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
        if #available(iOS 16, *) {
            logger.info("cannot add shortcut as passing data: urls to local server was disabled by apple on on iOS 16")
        } else {
            let addToHomescreenAction = UIAlertAction(title: String.localized("add_to_home_screen"), style: .default, handler: addToHomeScreen(_:))
            alert.addAction(addToHomescreenAction)
        }

        if sourceCodeUrl != nil {
            let sourceCodeAction = UIAlertAction(title: String.localized("source_code"), style: .default, handler: openUrl(_:))
            alert.addAction(sourceCodeAction)
        }

        let shareAction = UIAlertAction(title: String.localized("menu_share"), style: .default, handler: shareWebxdc(_:))
        alert.addAction(shareAction)

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

    private func shareWebxdc(_ action: UIAlertAction) {
        Utils.share(message: dcContext.getMessage(id: messageId), parentViewController: self, sourceItem: moreButton)
    }
}

extension WebxdcViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let handler = WebxdcHandler(rawValue: message.name) else { return }
        switch handler {
        case .log:
            guard let msg = message.body as? String else {
                logger.error("could not convert param \(message.body) to string")
                return
            }
            logger.info("webxdc log msg: " + msg)

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
            if let dict = message.body as? [String: AnyObject] {
                let title: String
                if let name = dict["name"] as? String {
                    title = String.localizedStringWithFormat(String.localized("send_file_to"), name)
                } else {
                    title = String.localized("send_message_to")
                }

                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                alert.addAction(UIAlertAction(title: String.localized("select_chat"), style: .default, handler: { _ in
                    let base64 = dict["base64"] as? String
                    let data = base64 != nil ? Data(base64Encoded: base64 ?? "") : nil
                    RelayHelper.shared.setForwardMessage(dialogTitle: title, text: dict["text"] as? String, fileData: data, fileName: dict["name"] as? String)

                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                       let rootController = appDelegate.appCoordinator.tabBarController.selectedViewController as? UINavigationController {
                        appDelegate.appCoordinator.showTab(index: appDelegate.appCoordinator.chatsTab)
                        rootController.popToRootViewController(animated: false)
                    }
                }))
                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }

        case .sendRealtimeAdvertisement:
            dcContext.sendWebxdcRealtimeAdvertisement(messageId: messageId)

        case .sendRealtimeData:
            if let uint8Array = message.body as? [UInt8] {
                dcContext.sendWebxdcRealtimeData(messageId: messageId, uint8Array: uint8Array)
            }

        case .leaveRealtime:
            dcContext.leaveWebxdcRealtime(messageId: messageId)
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
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    }
}
