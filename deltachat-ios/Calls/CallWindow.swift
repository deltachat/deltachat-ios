import UIKit

class CallWindow: UIWindow {
    static var shared: CallWindow? {
        (UIApplication.shared.delegate as? AppDelegate)?.callWindow
    }

    weak var callViewController: CallViewController?

    override var isHidden: Bool {
        didSet {
            isUserInteractionEnabled = !isHidden
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        rootViewController = UIViewController()
        // Required to show above input accessory view (eg the message bar on chat vc)
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
        showCallUI()
    }

    /// Show call UI for current call
    func showCallUI() {
        guard callViewController?.call.uuid != nil else { return }
        isHidden = false
        makeKey() // This makes sure the keyboard hides
    }

    func hideCallUI() {
        isHidden = true
        UIApplication.shared.delegate?.window??.makeKey()
    }

    func quitCallUI() {
        hideCallUI()
        rootViewController = UIViewController()
    }
}
