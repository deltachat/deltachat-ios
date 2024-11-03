import UIKit
import DcCore

public protocol ChatEditingDelegate: AnyObject {
    func onDeletePressed()
    func onForwardPressed()
    func onCancelPressed()
    func onCopyPressed()
    func onMorePressed()
}

public class ChatEditingBar: UIView {
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}

    public var isEnabled: Bool {
        willSet(newValue) {
            moreButton.isEnabled = newValue
            deleteButton.isEnabled = newValue
            forwardButton.isEnabled = newValue
            copyButton.isEnabled = newValue
        }
    }

    weak var delegate: ChatEditingDelegate?

    public lazy var moreButton: UIButton = {
        let view = UIButton()
        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        } else {
            view.setImage(UIImage(named: "ic_more"), for: .normal)
        }
        view.tintColor = .systemBlue
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.imageView?.contentMode = .scaleAspectFit
        view.accessibilityLabel = String.localized("menu_more_options")
        return view
    }()

    private lazy var copyButton: UIButton = {
        let view = UIButton()
        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
            view.tintColor = .systemBlue
        } else {
            view.setTitle(String.localized("copy"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
        }
        view.setTitleColor(.systemBlue, for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.imageView?.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        view.accessibilityLabel = String.localized("menu_copy_text_to_clipboard")
        return view
    }()

    public lazy var deleteButton: UIButton = {
        let view = UIButton()

        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "trash"), for: .normal)
            view.tintColor = .systemRed
        } else {
            view.setTitle(String.localized("delete"), for: .normal)
            view.setTitleColor(.systemRed, for: .normal)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.imageView?.contentMode = .scaleAspectFit
        view.accessibilityLabel = String.localized("delete")
        return view
    }()

    public lazy var forwardButton: UIButton = {
        let view = UIButton()
        view.tintColor = .systemBlue
        if #available(iOS 16.0, *) {
            view.setImage(UIImage(systemName: "arrowshape.forward.fill"), for: .normal)
        } else {
            view.setImage(UIImage(named: "ic_forward_white_36pt"), for: .normal)
            view.imageEdgeInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 0)
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.accessibilityLabel = String.localized("forward")
        return view
    }()

    private lazy var mainContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [forwardButton, copyButton, deleteButton, moreButton])
        view.axis = .horizontal
        view.distribution = .fillEqually
        view.alignment = .top
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public override init(frame: CGRect) {
        isEnabled = false
        super.init(frame: frame)
        self.setupSubviews()
        if #available(iOS 13.0, *) {
            backgroundColor = .systemBackground
        } else {
            backgroundColor = .white
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupSubviews() {
        addSubview(mainContentView)

        addConstraints([
            mainContentView.constraintAlignTopTo(self, paddingTop: 4),
            mainContentView.constraintAlignBottomTo(self, paddingBottom: 4),
            mainContentView.constraintAlignLeadingTo(self),
            mainContentView.constraintAlignTrailingTo(self),
            deleteButton.constraintHeightTo(36),
            forwardButton.constraintHeightTo(36),
            copyButton.constraintHeightTo(36),
            moreButton.constraintHeightTo(36)
        ])

        copyButton.addTarget(self, action: #selector(ChatEditingBar.onCopyPressed), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(ChatEditingBar.onMorePressed), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(ChatEditingBar.onForwardPressed), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(ChatEditingBar.onDeletePressed), for: .touchUpInside)
    }

    @objc func onCopyPressed() {
        delegate?.onCopyPressed()
    }

    @objc func onMorePressed() {
        delegate?.onMorePressed()
    }

    @objc func onForwardPressed() {
        delegate?.onForwardPressed()
    }

    @objc func onDeletePressed() {
        delegate?.onDeletePressed()
    }
}
