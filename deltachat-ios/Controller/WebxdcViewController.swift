import ActivityKit
import Combine
import DcCore
import UIKit
import WebKit

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
    var isDraft: Bool = false
    var href: String?
    var info: WebxdcInfo? {
        didSet {
            guard let info, info != oldValue, #available(iOS 16.2, *) else { return }
            updateLiveActivity(with: info)
        }
    }

    private lazy var moreButton: UIBarButtonItem = {
        let image = UIImage(systemName: .ellipsisNavigation())
        return UIBarButtonItem(image: image, menu: moreButtonMenu())
    }()

    private var advertiseAgainCancelable: AnyCancellable?

    var canMinimize: Bool {
        if #available(iOS 16.2, *) {
            ActivityAuthorizationInfo().areActivitiesEnabled
        } else {
            false
        }
    }
    private lazy var minimizeButton: UIBarButtonItem? = {
        !canMinimize ? nil : UIBarButtonItem( // TODO: Localized accessibility title?
            image: UIImage(systemName: "chevron.up"),
            primaryAction: UIAction(handler: { [weak self] _ in
                guard let self, #available(iOS 16.2, *), let info else { return }
                Self.loadedWebxdcs[.key(contextId: dcContext.id, messageId: messageId)] = self
                if #available(iOS 17.0, *) {
                    webView.configuration.preferences.inactiveSchedulingPolicy = .none
                }
                navigationController?.popViewController(withAnimation: .popToLiveActivity)
                startLiveActivity(with: info)
            })
        )
    }()

    @available(iOS 16.2, *)
    private var activity: Activity<WebxdcLiveActivityAttributes>? {
        get { _activity as? Activity<WebxdcLiveActivityAttributes> }
        set { _activity = newValue }
    }
    private var _activity: Any?

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
        let addr = info?.selfAddr.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.urlQueryAllowed
        )?.nilIfEmpty ?? "ErrAddr"
        let displayname = dcContext.displayname?.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.urlQueryAllowed
        )?.nilIfEmpty ?? String.localized("unnamed")

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
                if (!(data instanceof Uint8Array)) {
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
            selfAddr: decodeURI("\(addr)"),
            selfName: decodeURI("\(displayname)"),
            sendUpdateInterval: \(info?.sendUpdateInterval ?? 0),
            sendUpdateMaxSize: \(info?.sendUpdateMaxSize ?? 0),
            isAppSender: \(info?.isAppSender == true),
            isBroadcast: \(info?.isBroadcast == true),

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
        
            sendUpdate: (payload) => {
                webkit.messageHandlers.sendStatusUpdate.postMessage(payload);
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
        
        contentController.add(weak: self, name: WebxdcHandler.sendStatusUpdate.rawValue)
        contentController.add(weak: self, name: WebxdcHandler.log.rawValue)
        contentController.add(weak: self, name: WebxdcHandler.sendToChat.rawValue)
        contentController.add(weak: self, name: WebxdcHandler.sendRealtimeAdvertisement.rawValue)
        contentController.add(weak: self, name: WebxdcHandler.sendRealtimeData.rawValue)
        contentController.add(weak: self, name: WebxdcHandler.leaveRealtime.rawValue)

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
        config.setURLSchemeHandler(weak: self, forURLScheme: INTERNALSCHEMA)

        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true
        preferences.isFraudulentWebsiteWarningEnabled = true
        
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences = preferences
        return config
    }

    enum Key: Hashable {
        case key(contextId: Int, messageId: Int)
    }
    static var loadedWebxdcs: [Key: WebxdcViewController] = [:]

    class func `for`(dcContext: DcContext, messageId: Int, href: String? = nil) -> (vc: WebxdcViewController, pushAnimation: UIViewControllerAnimatedTransitioning?) {
        if let loaded = loadedWebxdcs[.key(contextId: dcContext.id, messageId: messageId)] {
            loaded.href = href
            return (loaded, .pushFromLiveActivity)
        }
        return (WebxdcViewController(dcContext: dcContext, messageId: messageId, href: href), nil)
    }

    init(dcContext: DcContext, messageId: Int, href: String? = nil) {
        self.messageId = messageId
        self.href = href
        super.init(dcContext: dcContext)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleMessagesChanged), name: Event.messagesChanged, object: nil)
        nc.addObserver(self, selector: #selector(handleMessageReadDeliveredReactionFailed), name: Event.messageReadDeliveredFailedReaction, object: nil)
        nc.addObserver(self, selector: #selector(handleWebxdcStatusUpdate), name: Event.webxdcStatusUpdate, object: nil)
        nc.addObserver(self, selector: #selector(handleWebxdcRealtimeDataReceived), name: Event.webxdcRealtimeDataReceived, object: nil)
        nc.addObserver(self, selector: #selector(handleConnectivityChanged), name: Event.connectivityChanged, object: nil)
        nc.addObserver(self, selector: #selector(applicationWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
        refreshWebxdcInfo()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        logger.info("⬅️ leave realtime by deinit")
        dcContext.leaveWebxdcRealtime(messageId: messageId)
        if #available(iOS 16.2, *) {
            endLiveActivity()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = moreButton
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [unowned self] _ in
                quit()
            }),
            minimizeButton
        ].compactMap(\.self)
    }

    func refreshWebxdcInfo() {
        let msg = dcContext.getMessage(id: messageId)
        info = msg.getWebxdcInfo()
        if info == nil {
            logger.error("Failed to decode WebxdcInfo")
            assertionFailure()
        }

        let chatName = dcContext.getChat(chatId: msg.chatId).name

        isDraft = msg.state == DC_STATE_OUT_DRAFT
        if isDraft {
            title = String.localized("draft")
        } else {
            title = "\(info?.document?.nilIfEmpty ?? msg.getWebxdcAppName()) – \(chatName)"
        }
    }

    // MARK: - Notifications

    @objc private func handleWebxdcRealtimeDataReceived(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let messageId = userInfo["message_id"] as? Int,
              messageId == self.messageId,
              let data = userInfo["data"] as? Data
        else { return }

        let byteArray = [UInt8](data)
        let commaSeparatedString = byteArray.map { String($0) }.joined(separator: ",")

        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript("window.__webxdcRealtimeData([" + commaSeparatedString + "])")
        }
    }

    @objc private func handleWebxdcStatusUpdate(_ notification: Notification) {
        guard let messageId = notification.userInfo?["message_id"] as? Int,
              messageId == self.messageId else { return }

        DispatchQueue.main.async { [weak self] in
            self?.updateWebxdc()
        }
    }

    @objc private func handleMessagesChanged(_ notification: Notification) {
        guard let messageId = notification.userInfo?["message_id"] as? Int,
              messageId == self.messageId
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.refreshWebxdcInfo()
        }
    }

    @objc private func handleMessageReadDeliveredReactionFailed(_ notification: Notification) {
        guard let messageId = notification.userInfo?["message_id"] as? Int,
              messageId == self.messageId
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.refreshWebxdcInfo()
        }
    }

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        guard dcContext.id == notification.userInfo?["account_id"] as? Int else { return }
        DispatchQueue.main.async { [weak self] in
            guard #available(iOS 16.2, *), let self, let info else { return }
            updateLiveActivity(with: info)
        }
    }

    @objc private func applicationWillTerminate(_: Notification) {
        if #available(iOS 16.2, *) {
            endLiveActivity()
        }
    }

    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            return decisionHandler(.allow)
        }
        switch url.scheme?.lowercased() {
        case INTERNALSCHEMA,
            "about" where url.absoluteString == "about:srcdoc":
            decisionHandler(.allow)
        case "mailto":
            openChatFor(url: url)
            decisionHandler(.cancel)
        case "https" where url.host == Utils.inviteDomain,
             "openpgp4fpr":
            _ = UIApplication.shared.delegate?.application?(UIApplication.shared, open: url)
            decisionHandler(.cancel)
        case "geo":
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        case "https", "http":
            let alert = UIAlertController(
                title: String.localized("open_url_confirmation"),
                message: url.absoluteString.removingPercentEncoding,
                preferredStyle: .safeActionSheet
            )
            alert.addAction(UIAlertAction(title: String.localized("open"), style: .default) { _ in
                UIApplication.shared.open(url)
            })
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
            present(alert, animated: true)
            decisionHandler(.cancel)
        default:
            decisionHandler(.cancel)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if info?.internetAccess == true {
            loadHtml()
        } else {
            loadRestrictedHtml()
        }
    }

    private func loadRestrictedHtml() {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "WebxdcContentBlockingRules",
            encodedContentRuleList: blockRules) { (contentRuleList, error) in
                guard let contentRuleList, error == nil else { return }
                let configuration = self.webView.configuration
                configuration.userContentController.add(contentRuleList)
                self.loadHtml()
            }
    }
    
    @MainActor private func loadHtml() {
        assert(Thread.isMainThread)
        let base = "\(self.INTERNALSCHEMA)://acc\(self.dcContext.id)-msg\(self.messageId).localhost/"
        let url = URL(string: base + (href ?? "index.html"))
        let urlRequest = URLRequest(url: url ?? URL(string: base + "index.html")!)
        if self.webView.url != urlRequest.url {
            self.webView.load(urlRequest)
        }
    }

    private func updateWebxdc() {
        webView.evaluateJavaScript("window.__webxdcUpdate()", completionHandler: nil)
    }

    func quit() {
        Self.loadedWebxdcs[.key(contextId: dcContext.id, messageId: messageId)] = nil
        let vcs = navigationController?.viewControllers.filter { $0 != self } ?? []
        navigationController?.setViewControllers(vcs, animated: true)
    }

    private func moreButtonMenu() -> UIMenu {
        let actions: () -> [UIMenuElement] = { [weak self] in
            guard let self else { return [] }
            var actions = [UIMenuElement]()

            if !isDraft {
                actions.append(UIAction(title: String.localized("show_in_chat"), image: UIImage(systemName: "doc.text.magnifyingglass")) { [weak self] _ in
                    guard let self, let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
                    let message = dcContext.getMessage(id: self.messageId)
                    DispatchQueue.main.async {
                        appDelegate.appCoordinator.showChat(chatId: message.chatId, msgId: message.id, animated: true, clearViewControllerStack: true)
                    }
                })

                if #available(iOS 17.0, *), let userDefaults = UserDefaults.shared {
                    let appsInWidgetsMessageIds = userDefaults.getAppWidgetEntries().compactMap { entry in
                        switch entry.type {
                        case .app(let messageId): return messageId
                        case .chat: return nil
                        }
                    }
                    let isOnHomescreen = appsInWidgetsMessageIds.contains(messageId)
                    if isOnHomescreen {
                        actions.append(UIAction(title: String.localized("remove_from_widget"), image: UIImage(systemName: "minus.square")) { [weak self] _ in
                            guard let self else { return }
                            userDefaults.removeWebxdcFromHomescreen(accountId: dcContext.id, messageId: messageId)
                        })
                    } else {
                        actions.append(UIAction(title: String.localized("add_to_widget"), image: UIImage(systemName: "plus.square")) { [weak self] _ in
                            guard let self else { return }
                            userDefaults.addWebxdcToHomescreenWidget(accountId: dcContext.id, messageId: messageId)
                        })
                    }
                }
            }

            var helpActions = [UIMenuElement]()
            helpActions.append(UIAction(title: String.localized("what_is_webxdc"), image: UIImage(systemName: "questionmark.circle")) { [weak self] _ in
                self?.openHelp(fragment: "#webxdc")
            })
            if let url = info?.sourceCodeUrl, !url.isEmpty {
                helpActions.append(UIAction(title: String.localized("source_code"), image: UIImage(systemName: "arrow.up.right")) { [weak self] _ in
                    self?.openSourceCodeUrl()
                })
            }
            actions.append(UIMenu(options: [.displayInline], children: helpActions))

            return actions
        }

        // uncached() allows us to update the menu easily; needed for widget state.
        // UIDeferredMenuElement speeds up opening as complex checks are delayed until the menu is used.
        return UIMenu(children: [
            UIDeferredMenuElement.uncached({ completion in
                completion(actions())
            })
        ])
    }

    private func openSourceCodeUrl() {
        if let url = URL(string: info?.sourceCodeUrl ?? "") {
            UIApplication.shared.open(url)
        }
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
            guard let payloadDict = message.body as? [String: AnyObject],
                  let payloadJson = try? JSONSerialization.data(withJSONObject: payloadDict, options: []),
                  let payloadString = String(data: payloadJson, encoding: .utf8) else {
                      logger.error("Failed to parse status update parameters \(message.body)")
                      return
                  }
            _ = dcContext.sendWebxdcStatusUpdate(msgId: messageId, payload: payloadString)

        case .sendToChat:
            if let dict = message.body as? [String: AnyObject] {
                let title: String
                if let name = dict["name"] as? String {
                    title = String.localizedStringWithFormat(String.localized("send_file_to"), name)
                } else {
                    title = String.localized("send_message_to")
                }

                let alert = UIAlertController(title: title, message: nil, preferredStyle: .safeActionSheet)
                let selectAction = UIAlertAction(title: String.localized("select_chat"), style: .default, handler: { _ in
                    let base64 = dict["base64"] as? String
                    let data = base64 != nil ? Data(base64Encoded: base64 ?? "") : nil
                    RelayHelper.shared.setForwardMessage(dialogTitle: title, text: dict["text"] as? String, fileData: data, fileName: dict["name"] as? String)

                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
                       let rootController = appDelegate.appCoordinator.tabBarController.selectedViewController as? UINavigationController {
                        appDelegate.appCoordinator.showTab(index: appDelegate.appCoordinator.chatsTab)
                        rootController.popToRootViewController(animated: false)
                    }
                })
                selectAction.setValue(UIImage(systemName: "paperplane"), forKey: "image")
                alert.addAction(selectAction)

                if let name = dict["name"] as? String {
                    let shareAction = UIAlertAction(title: String.localized("menu_share"), style: .default, handler: { [weak self] _ in
                        guard let self else { return }
                        if let base64 = dict["base64"] as? String, let data = Data(base64Encoded: base64), let sourceItem = navigationItem.rightBarButtonItem {
                            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                            try? FileManager.default.removeItem(at: fileURL)
                            try? data.write(to: fileURL)
                            Utils.share(url: fileURL, parentViewController: self, sourceItem: sourceItem)
                        }
                    })
                    shareAction.setValue(UIImage(systemName: "square.and.arrow.up"), forKey: "image")
                    alert.addAction(shareAction)
                }

                alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }

        case .sendRealtimeAdvertisement:
            logger.info("➡️ send realtime advertisement")
            dcContext.sendWebxdcRealtimeAdvertisement(messageId: messageId)
            advertiseAgainCancelable = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .map { _ in UserDefaults.mainIoRunning }
                .removeDuplicates()
                .debounce(for: .seconds(1), scheduler: RunLoop.main)
                .sink { [weak self] mainIoRunning in
                    guard let self, mainIoRunning else { return }
                    dcContext.sendWebxdcRealtimeAdvertisement(messageId: messageId)
                }

        case .sendRealtimeData:
            if let uint8Array = message.body as? [UInt8] {
                dcContext.sendWebxdcRealtimeData(messageId: messageId, uint8Array: uint8Array)
            }

        case .leaveRealtime:
            logger.info("⬅️ leave realtime by xdc request")
            dcContext.leaveWebxdcRealtime(messageId: messageId)
            advertiseAgainCancelable = nil
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

            if self.info?.internetAccess != true {
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

@available(iOS 16.2, *)
extension WebxdcViewController {

    private func startLiveActivity(with info: WebxdcInfo) {
        Task { [self] in
            await activity?.end(nil, dismissalPolicy: .immediate)
            let attributes = WebxdcLiveActivityAttributes(context: dcContext, messageId: messageId)
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: .init(
                        state: .init(info: info, connectivity: dcContext.getConnectivity()),
                        staleDate: nil
                    )
                )
            } catch {
                logger.error(error.localizedDescription)
            }
        }
    }

    private func updateLiveActivity(with info: WebxdcInfo) {
        Task { [activity, dcContext] in
            await activity?.update(.init(
                state: .init(info: info, connectivity: dcContext.getConnectivity()),
                staleDate: nil
            ))
            print("updated", dcContext.getConnectivity())
        }
    }

    private func endLiveActivity() {
        Task { [activity] in
            await activity?.end(nil, dismissalPolicy: .immediate)
        }
    }
}

// MARK: Memory Leak Prevention

extension WKUserContentController {
    func add(weak scriptMessageHandler: any WKScriptMessageHandler, name: String) {
        add(WeakScriptMessageHandler(scriptMessageHandler), name: name)
    }

    private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
        weak var scriptMessageHandler: WKScriptMessageHandler?

        init(_ scriptMessageHandler: WKScriptMessageHandler) {
            self.scriptMessageHandler = scriptMessageHandler
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            scriptMessageHandler?.userContentController(userContentController, didReceive: message)
        }
    }
}

extension WKWebViewConfiguration {
    func setURLSchemeHandler(weak urlSchemeHandler: (any WKURLSchemeHandler), forURLScheme urlScheme: String) {
        setURLSchemeHandler(WeakURLSchemeHandler(urlSchemeHandler), forURLScheme: urlScheme)
    }

    private class WeakURLSchemeHandler: NSObject, WKURLSchemeHandler {
        weak var urlSchemeHandler: WKURLSchemeHandler?

        init(_ urlSchemeHandler: WKURLSchemeHandler) {
            self.urlSchemeHandler = urlSchemeHandler
        }

        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            urlSchemeHandler?.webView(webView, start: urlSchemeTask)
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
            urlSchemeHandler?.webView(webView, stop: urlSchemeTask)
        }
    }
}

extension UIViewControllerAnimatedTransitioning where Self == PopToLiveActivityAnimation {
    static var popToLiveActivity: Self { PopToLiveActivityAnimation() }
}

class PopToLiveActivityAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.5
    }
    
    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to)
        else { return transitionContext.completeTransition(false) }

        transitionContext.containerView.insertSubview(toView, belowSubview: fromView)

        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: .curveEaseOut) {
            fromView.transform = .init(translationX: 0, y: -fromView.bounds.height).scaledBy(x: 0.7, y: 0.7)
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            fromView.transform = .identity
        }
    }
}

extension UIViewControllerAnimatedTransitioning where Self == PushFromLiveActivityAnimation {
    static var pushFromLiveActivity: Self { PushFromLiveActivityAnimation() }
}

class PushFromLiveActivityAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        0.5
    }

    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to) else {
            return transitionContext.completeTransition(false)
        }

        transitionContext.containerView.addSubview(toView)
        toView.transform = CGAffineTransform(translationX: 0, y: -toView.bounds.height).scaledBy(x: 0.7, y: 0.7)

        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: .curveEaseOut) {
            toView.transform = .identity
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

extension UINavigationController {
    private class AnimationProvidingDelegate: NSObject, UINavigationControllerDelegate {
        var animation: UIViewControllerAnimatedTransitioning?

        internal init(animation: any UIViewControllerAnimatedTransitioning?) {
            self.animation = animation
        }

        func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
            animation
        }
    }

    func pushViewController(_ viewController: UIViewController, withAnimation animation: UIViewControllerAnimatedTransitioning?) {
        let oldDelegate = self.delegate
        let tempDelegate = AnimationProvidingDelegate(animation: animation)
        self.delegate = tempDelegate
        pushViewController(viewController as UIViewController, animated: true)
        self.delegate = oldDelegate
    }

    func popViewController(withAnimation animation: UIViewControllerAnimatedTransitioning?) {
        let oldDelegate = self.delegate
        let tempDelegate = AnimationProvidingDelegate(animation: animation)
        self.delegate = tempDelegate
        popViewController(animated: true)
        self.delegate = oldDelegate
    }

    func setViewControllers(_ viewControllers: [UIViewController], withAnimation animation: UIViewControllerAnimatedTransitioning?) {
        let oldDelegate = self.delegate
        let tempDelegate = AnimationProvidingDelegate(animation: animation)
        self.delegate = tempDelegate
        setViewControllers(viewControllers, animated: true)
        self.delegate = oldDelegate
    }
}
