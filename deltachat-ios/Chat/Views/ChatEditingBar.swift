import UIKit
import DcCore

public protocol ChatEditingDelegate: class {
    func onDeletePressed()
    func onForwardPressed()
    func onCancelPressed()
}

public class ChatEditingBar: UIView, InputItem {
    public var inputBarAccessoryView: InputBarAccessoryView?
    public var parentStackViewPosition: InputStackView.Position?
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}


    public var isEnabled: Bool {
        willSet(newValue) {
            deleteButton.isEnabled = newValue
            forwardButton.isEnabled = newValue
        }
    }

    weak var delegate: ChatEditingDelegate?

    private lazy var cancelButton: UIButton = {
        let view = UIButton()
        view.setTitle(String.localized("cancel"), for: .normal)
        view.setTitleColor(.systemBlue, for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.imageView?.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        return view
    }()

    public lazy var deleteButton: UIButton = {
        let view = UIButton()

        if #available(iOS 13.0, *) {
            view.setImage(UIImage(systemName: "trash"), for: .normal)
            view.tintColor = .systemBlue
        } else {
            view.setTitle(String.localized("delete"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
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
        view.setImage( #imageLiteral(resourceName: "ic_forward_white_36pt").withRenderingMode(.alwaysTemplate), for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.imageView?.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        view.accessibilityLabel = String.localized("forward")
        return view
    }()

    private lazy var mainContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [cancelButton, forwardButton, deleteButton])
        view.axis = .horizontal
        view.distribution = .fillEqually
        view.alignment = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    convenience init() {
        self.init(frame: .zero)

    }

    public override init(frame: CGRect) {
        isEnabled = false
        super.init(frame: frame)
        self.setupSubviews()
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
            forwardButton.constraintHeightTo(26),
            cancelButton.constraintHeightTo(36),
        ])

        let cancelGestureListener = UITapGestureRecognizer(target: self, action: #selector(onCancelPressed))
        cancelButton.addGestureRecognizer(cancelGestureListener)

        let forwardGestureListener = UITapGestureRecognizer(target: self, action: #selector(onForwardPressed))
        forwardButton.addGestureRecognizer(forwardGestureListener)

        let deleteGestureListener = UITapGestureRecognizer(target: self, action: #selector(onDeletePressed))
        deleteButton.addGestureRecognizer(deleteGestureListener)
    }

    @objc func onCancelPressed() {
        delegate?.onCancelPressed()
    }

    @objc func onForwardPressed() {
        delegate?.onForwardPressed()
    }

    @objc func onDeletePressed() {
        delegate?.onDeletePressed()
    }
}
