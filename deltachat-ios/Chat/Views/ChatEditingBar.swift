import UIKit
import DcCore

public protocol ChatEditingDelegate: AnyObject {
    func onDeletePressed()
    func onForwardPressed()
    func onCancelPressed()
    func onCopyPressed()
    func onMorePressed() -> UIMenu
}

public class ChatEditingBar: UIView {
    public var isEnabled: Bool {
        willSet(newValue) {
            moreButton.isEnabled = newValue
            deleteButton.isEnabled = newValue
            forwardButton.isEnabled = newValue
            copyButton.isEnabled = newValue
        }
    }

    weak var delegate: ChatEditingDelegate?

    public lazy var moreButton: UIBarButtonItem = {
        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: UIMenu(children: [
                UIDeferredMenuElement.uncached({ [weak self] completion in
                    completion(self?.delegate?.onMorePressed().children ?? [])
                })
            ])
        )
        moreButton.accessibilityLabel = String.localized("menu_more_options")
        return moreButton
    }()

    private lazy var copyButton: UIBarButtonItem = {
        let view = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: self,
            action: #selector(onCopyPressed)
        )
        view.accessibilityLabel = String.localized("menu_copy_text_to_clipboard")
        return view
    }()

    public lazy var deleteButton: UIBarButtonItem = {
        let view = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(onDeletePressed)
        )
        view.tintColor = .systemRed
        view.accessibilityLabel = String.localized("delete")
        return view
    }()

    public lazy var forwardButton: UIBarButtonItem = {
        let view = UIBarButtonItem(
            image: UIImage(systemName: "arrowshape.turn.up.forward"),
            style: .plain,
            target: self,
            action: #selector(onForwardPressed)
        )
        view.accessibilityLabel = String.localized("forward")
        return view
    }()

    private lazy var toolbar: UIToolbar = {
        let view = UIToolbar()
        view.items = [forwardButton, copyButton, deleteButton, .flexibleSpace(), moreButton]
        return view
    }()

    public override init(frame: CGRect) {
        isEnabled = false
        super.init(frame: frame)
        self.setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupSubviews() {
        addSubview(toolbar)
        toolbar.fillSuperviewAvoidingSafeAreaAndKeyboard()
    }

    @objc func onCopyPressed() {
        delegate?.onCopyPressed()
    }

    @objc func onForwardPressed() {
        delegate?.onForwardPressed()
    }

    @objc func onDeletePressed() {
        delegate?.onDeletePressed()
    }
}
