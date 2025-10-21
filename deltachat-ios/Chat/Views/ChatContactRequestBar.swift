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

public class ChatContactRequestBar: UIView, InputItem {
    public weak var inputBarAccessoryView: InputBarAccessoryView?
    public var parentStackViewPosition: InputStackView.Position?
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}

    weak var delegate: ChatContactRequestDelegate?
    
    private let notAcceptMeaning: NotAcceptMeaning
    private let infoText: String?

    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(for: .body, weight: .regular)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textColor = DcColors.defaultInverseColor
        label.textAlignment = .center
        label.text = infoText
        return label
    }()

    private lazy var acceptButton: DynamicFontButton = {
        let view = DynamicFontButton()
        view.setTitle(String.localized("accept"), for: .normal)
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
        view.setTitle(String.localized(notAcceptMeaning == .delete ? "delete" : "block"), for: .normal)
        view.setTitleColor(.systemRed, for: .normal)
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

    public required init(_ notAcceptMeaning: NotAcceptMeaning, infoText: String?) {
        self.notAcceptMeaning = notAcceptMeaning
        self.infoText = infoText
        super.init(frame: .zero)
        setupSubviews(infoText: infoText)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setupSubviews(infoText: String?) {
        let buttons = UIStackView(arrangedSubviews: [notAcceptButton, acceptButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.alignment = .fill

        let mainContentView = UIStackView(arrangedSubviews: infoText == nil ? [buttons] : [infoLabel, buttons])
        mainContentView.axis = .vertical
        mainContentView.distribution = .fillEqually
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
        }
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: super.intrinsicContentSize.width, height: infoText == nil ? 44 : 110)
    }
}
