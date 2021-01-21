import UIKit
import InputBarAccessoryView
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


    weak var delegate: ChatEditingDelegate?

    private lazy var cancelImageView: UIButton = {
        let view = UIButton()
        view.tintColor = .systemBlue
        view.setImage(#imageLiteral(resourceName: "ic_close_36pt").withRenderingMode(.alwaysTemplate), for: .normal)
        view.adjustsImageWhenHighlighted = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var deleteImageView: UIButton = {
        let view = UIButton()
        view.tintColor = .red
        view.setImage( #imageLiteral(resourceName: "ic_delete").withRenderingMode(.alwaysTemplate), for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        view.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var forwardImageView: UIButton = {
        let view = UIButton()
        view.tintColor = DcColors.defaultTextColor
        view.setImage( #imageLiteral(resourceName: "ic_forward_white_36pt").withRenderingMode(.alwaysTemplate), for: .normal)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        return view
    }()

    private lazy var mainContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [deleteImageView, forwardImageView, cancelImageView])
        view.axis = .horizontal
        view.distribution = .equalSpacing
        view.alignment = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        view.spacing = 16
        return view
    }()

    convenience init() {
        self.init(frame: .zero)

    }

    public override init(frame: CGRect) {
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
            deleteImageView.constraintHeightTo(36),
            deleteImageView.constraintWidthTo(36),
            forwardImageView.constraintHeightTo(36),
            forwardImageView.constraintWidthTo(36),
            cancelImageView.constraintHeightTo(36),
            cancelImageView.constraintWidthTo(36)
        ])

        backgroundColor = DcColors.chatBackgroundColor

        let cancelGestureListener = UITapGestureRecognizer(target: self, action: #selector(onCancelPressed))
        cancelImageView.addGestureRecognizer(cancelGestureListener)

        let forwardGestureListener = UITapGestureRecognizer(target: self, action: #selector(onForwardPressed))
        forwardImageView.addGestureRecognizer(forwardGestureListener)

        let deleteGestureListener = UITapGestureRecognizer(target: self, action: #selector(onDeletePressed))
        deleteImageView.addGestureRecognizer(deleteGestureListener)
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
