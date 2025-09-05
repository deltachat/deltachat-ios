import DcCore
import UIKit
import WebKit

class CallWindow: UIWindow {
    static var shared: CallWindow? {
        (UIApplication.shared.delegate as? AppDelegate)?.callWindow
    }
    
    private weak var callViewController: CallViewController?

    override var isHidden: Bool {
        didSet {
            isUserInteractionEnabled = !isHidden
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        rootViewController = UIViewController()
        windowLevel = .alert
        makeKeyAndVisible()
        isHidden = true
    }
    
    @available(*, unavailable) required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showCallUI(for call: DcCall) {
        if callViewController?.call.uuid != call.uuid {
            let new = CallViewController(call: call)
            rootViewController = new
            callViewController = new
        }
        isHidden = false
    }
    
    func hideCallUI() {
        isHidden = true
    }
    
    func hideCallUIAndSetRoot() {
        hideCallUI()
        rootViewController = UIViewController()
    }
}

class CallViewController: UIViewController {
    var call: DcCall

    lazy var config: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        let contentController = WKUserContentController()
        let scriptSource = """
            window.calls = {
              startCall: (payload) => {
                console.log("startCall() called: " + payload);
                webkit.messageHandlers.startCall.postMessage(payload);
              },
              acceptCall: (payload) => {
                console.log("acceptCall() called: " + payload);
                webkit.messageHandlers.acceptCall.postMessage(payload);
              },
              endCall: () => {
                console.log("endCall() called");
                webkit.messageHandlers.endCall.postMessage("");
              },
            };
            """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)

        contentController.addUserScript(script)
        contentController.add(weak: self, name: "startCall")
        contentController.add(weak: self, name: "acceptCall")
        contentController.add(weak: self, name: "endCall")
        config.userContentController = contentController
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true
        config.preferences = preferences

        return config
    }()

    lazy var webView: WKWebView = {
        let webView = WKWebView(frame: view.frame, configuration: config)
        webView.uiDelegate = self
        return webView
    }()
    
    lazy var hideButton: UIButton = {
        let button = UIButton(type: .close)
        button.addTarget(self, action: #selector(hideButtonPressed), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init(call: DcCall) {
        self.call = call
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CallViewController.handleOutgoingCallAcceptedEvent(_:)), name: Event.outgoingCallAccepted, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        webView.fillSuperview()

        guard let fileURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Assets/calls") else { return }
        guard var fileComponents = URLComponents(url: fileURL, resolvingAgainstBaseURL: false) else { return }
        switch call.direction {
        case .outgoing: fileComponents.percentEncodedFragment = "call"
        case .incoming: fileComponents.percentEncodedFragment = "offer=\(call.placeCallInfo ?? "ErrNoCallInfo")"
        }

        guard let urlWithFragment = fileComponents.url else { return }
        webView.load(URLRequest(url: urlWithFragment))

        view.addSubview(hideButton)
        hideButton.alignTopToAnchor(view.safeAreaLayoutGuide.topAnchor, paddingTop: 10)
        hideButton.alignLeadingToAnchor(view.safeAreaLayoutGuide.leadingAnchor, paddingLeading: 10)
    }
    
    @objc private func hideButtonPressed() {
        hangup()
    }

    private func hangup() {
        let dcContext = DcAccounts.shared.get(id: call.contextId)
        if let messageId = call.messageId {
            dcContext.endCall(msgId: messageId)
        } else {
            CallManager.shared.endCallControllerAndHideUI()
        }
    }

    func setWebviewFragment(fragment: String) {
        let js = "window.location.hash = '#\(fragment)';"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Notifications

    @objc private func handleOutgoingCallAcceptedEvent(_ notification: Notification) {
        guard let ui = notification.userInfo else { return }
        guard let accountId = ui["account_id"] as? Int, let msgId = ui["message_id"] as? Int else { return }
        guard accountId == call.contextId && msgId == call.messageId else { return }
        guard let acceptCallInfo = ui["accept_call_info"] as? String else { return }

        DispatchQueue.main.async { [weak self] in
            self?.setWebviewFragment(fragment: "answer=\(acceptCallInfo)")
        }
    }
}

extension CallViewController: WKUIDelegate {
    @available(iOS 15.0, *) func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

extension CallViewController: WKScriptMessageHandler {
    // receiving messages from the webview,
    // need to be declared in swift-land by contentController.add(FUNC_NAME)
    // and called in js-land as webkit.messageHandlers.FUNC_NAME.postMessage(payload)
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "startCall":
            guard let payload = message.body as? String else { logger.error("errStartCall: \(message.body)"); return }
            logger.info("startCall: " + payload)
            let dcContext = DcAccounts.shared.get(id: call.contextId)
            call.messageId = dcContext.placeOutgoingCall(chatId: call.chatId, placeCallInfo: payload)

        case "acceptCall":
            guard let payload = message.body as? String else { logger.error("errAcceptCall: \(message.body)"); return }
            guard let messageId = call.messageId else { logger.error("errAcceptCall: messageId not set"); return }
            logger.info("acceptCall: " + payload)
            let dcContext = DcAccounts.shared.get(id: call.contextId)
            call.callAcceptedHere = true
            dcContext.acceptIncomingCall(msgId: messageId, acceptCallInfo: payload)

        case "endCall":
            logger.info("endCall")
            hangup()

        default:
            logger.error("errMessageHandler: \(message.name)")
        }
    }
}
