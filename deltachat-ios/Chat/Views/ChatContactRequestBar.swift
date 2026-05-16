import UIKit
import DcCore

public enum NotAcceptMeaning: Error {
    case delete
    case block
}

public protocol ChatContactRequestDelegate: AnyObject {
    func onAcceptRequest()
    func onBlockRequest()
    func onDeleteRequest()
}

public class ChatContactRequestBar: UIView {
    weak var delegate: ChatContactRequestDelegate?

    private let notAcceptMeaning: NotAcceptMeaning

    private lazy var acceptButton: UIBarButtonItem = {
        let acceptButton = UIBarButtonItem(
            title: String.localized("accept"),
            style: .plain,
            target: self,
            action: #selector(onAcceptPressed)
        )
        return acceptButton
    }()

    private lazy var rejectButton: UIBarButtonItem = {
        let rejectButton = UIBarButtonItem(
            title: String.localized(notAcceptMeaning == .delete ? "delete" : "block"),
            style: .plain,
            target: self,
            action: #selector(onRejectPressed)
        )
        rejectButton.tintColor = .systemRed
        return rejectButton
    }()

    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.items = [rejectButton, acceptButton]
        return toolbar
    }()

    public required init(_ notAcceptMeaning: NotAcceptMeaning) {
        self.notAcceptMeaning = notAcceptMeaning
        super.init(frame: .zero)
        setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupSubviews() {
        addSubview(toolbar)
        toolbar.fillSuperviewAvoidingSafeAreaAndKeyboard()
    }

    @objc func onAcceptPressed() {
        delegate?.onAcceptRequest()
    }

    @objc func onRejectPressed() {
        switch notAcceptMeaning {
        case .delete:
            delegate?.onDeleteRequest()
        case .block:
            delegate?.onBlockRequest()
        }
    }
}
