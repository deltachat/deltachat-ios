import UIKit
import DcCore

public enum NotAcceptMeaning: Error {
    case delete
    case block
    case info
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
    
    private let notAcceptMeaning: NotAcceptMeaning

    private lazy var acceptButton: DynamicFontButton = {
        let view = DynamicFontButton()
        view.setTitle(String.localized(notAcceptMeaning == .info ? "ok" : "accept"), for: .normal)
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

    private lazy var notAcceptButton: DynamicFontButton = {
        let view = DynamicFontButton()
        switch notAcceptMeaning {
        case .delete, .block:
            view.setTitle(String.localized(notAcceptMeaning == .delete ? "delete" : "block"), for: .normal)
            view.setTitleColor(.systemRed, for: .normal)
        case .info:
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

    public required init(_ notAcceptMeaning: NotAcceptMeaning) {
        self.notAcceptMeaning = notAcceptMeaning
        super.init(frame: .zero)
        setupSubviews()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupSubviews() {
        let buttons = UIStackView(arrangedSubviews: [notAcceptButton, acceptButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.alignment = .fill

        let mainContentView = UIStackView(arrangedSubviews: [buttons])
        mainContentView.axis = .vertical
        mainContentView.alignment = .fill
        mainContentView.translatesAutoresizingMaskIntoConstraints = false
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
        notAcceptButton.addGestureRecognizer(blockGestureListener)

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
        case .info:
            delegate?.onShowInfoDialog()
        }
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: super.intrinsicContentSize.width, height: 44)
    }
}
