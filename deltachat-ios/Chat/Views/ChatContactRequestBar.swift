import UIKit
import DcCore

public enum NotAcceptButton: Error {
    case deleteButton
    case blockButton
    case infoButton
}

public protocol ChatContactRequestDelegate: class {
    func onAcceptRequest()
    func onBlockRequest()
    func onDeleteRequest()
    func onShowInfoDialog()
}

public class ChatContactRequestBar: UIView, InputItem {
    public var inputBarAccessoryView: InputBarAccessoryView?
    public var parentStackViewPosition: InputStackView.Position?
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}

    weak var delegate: ChatContactRequestDelegate?
    
    private let notAcceptButton: NotAcceptButton

    private lazy var acceptButton: DynamicFontButton = {
        let view = DynamicFontButton()
        view.setTitle(String.localized(notAcceptButton == .infoButton ? "ok" : "accept"), for: .normal)
        view.setTitleColor(.systemBlue, for: .normal)
        view.setTitleColor(.gray, for: .highlighted)
        view.titleLabel?.lineBreakMode = .byWordWrapping
        view.titleLabel?.textAlignment = .center
        view.contentHorizontalAlignment = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        view.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        view.titleLabel?.adjustsFontForContentSizeCategory = true
        return view
    }()

    private lazy var blockButton: DynamicFontButton = {
        let view = DynamicFontButton()
        switch notAcceptButton {
        case .deleteButton, .blockButton:
            view.setTitle(String.localized(notAcceptButton == .deleteButton ? "delete" : "block"), for: .normal)
            view.setTitleColor(.systemRed, for: .normal)
        case .infoButton:
            view.setTitle(String.localized("more_info_desktop"), for: .normal)
            view.setTitleColor(.systemBlue, for: .normal)
        }
        view.setTitleColor(.gray, for: .highlighted)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.titleLabel?.lineBreakMode = .byWordWrapping
        view.titleLabel?.textAlignment = .center
        view.contentHorizontalAlignment = .center
        view.isUserInteractionEnabled = true
        view.titleLabel?.font = UIFont.preferredFont(for: .body, weight: .regular)
        view.titleLabel?.adjustsFontForContentSizeCategory = true
        return view
    }()

    private lazy var mainContentView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [blockButton, acceptButton])
        view.axis = .horizontal
        view.distribution = .fillEqually
        view.alignment = .fill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public required init(_ notAcceptButton: NotAcceptButton) {
        self.notAcceptButton = notAcceptButton
        super.init(frame: .zero)
        setupSubviews()
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
        ])

        let acceptGestureListener = UITapGestureRecognizer(target: self, action: #selector(onAcceptPressed))
        acceptButton.addGestureRecognizer(acceptGestureListener)

        let blockGestureListener = UITapGestureRecognizer(target: self, action: #selector(onRejectPressed))
        blockButton.addGestureRecognizer(blockGestureListener)

    }

    @objc func onAcceptPressed() {
        delegate?.onAcceptRequest()
    }

    @objc func onRejectPressed() {
        switch notAcceptButton {
        case .deleteButton:
            delegate?.onDeleteRequest()
        case .blockButton:
            delegate?.onBlockRequest()
        case .infoButton:
            delegate?.onShowInfoDialog()
        }
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: super.intrinsicContentSize.width, height: 44)
    }
}
