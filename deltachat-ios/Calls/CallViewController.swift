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
    
    lazy var webView: WKWebView = {
        let webView = WKWebView(frame: view.frame)
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
        guard let fileURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Assets/calls") else { return }

        view.addSubview(webView)
        webView.fillSuperview()
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
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
