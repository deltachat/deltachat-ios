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
    
    func endCall() {
        hideCallUI()
        rootViewController = UIViewController()
    }
}

class CallViewController: UIViewController {
    var call: DcCall

    init(call: DcCall) {
        self.call = call
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        webView.fillSuperview()

        guard let fileURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Assets/calls") else { return }
        guard var fileComponents = URLComponents(url: fileURL, resolvingAgainstBaseURL: false) else { return }
        switch call.direction {
        case .outgoing: fileComponents.fragment = "call"
        case .incoming: fileComponents.fragment = "offer=\(call.placeCallInfo ?? "ErrNoCallInfo")"
        }

        guard let urlWithFragment = fileComponents.url else { return }
        webView.load(URLRequest(url: urlWithFragment))

        view.addSubview(hideButton)
        hideButton.alignTopToAnchor(view.safeAreaLayoutGuide.topAnchor, paddingTop: 10)
        hideButton.alignLeadingToAnchor(view.safeAreaLayoutGuide.leadingAnchor, paddingLeading: 10)
    }
    
    @objc private func hideButtonPressed() {
        CallWindow.shared?.hideCallUI()
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
            call.messageId = dcContext.placeOutgoingCall(chatId: call.chatId, payload: payload)

        case "acceptCall":
            guard let payload = message.body as? String else { logger.error("errAcceptCall: \(message.body)"); return }
            logger.info("acceptCall: " + payload)

        case "endCall":
            logger.info("endCall")

        default:
            logger.error("errMessageHandler: \(message.name)")
        }
    }
}
