import UIKit
import DcCore

public protocol ProtectionBrokenDelegate: class {
    func onBrokenProtectionInfo()
    func onAcceptBrokenProtection()
}

public class ProtectionBrokenBar: UIView, InputItem {
    public var inputBarAccessoryView: InputBarAccessoryView?
    public var parentStackViewPosition: InputStackView.Position?
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}

    weak var delegate: ProtectionBrokenDelegate?
    
    private var useDeleteButton: Bool = false

    private lazy var acceptButton: DynamicFontButton = {
        let view = DynamicFontButton()
        view.setTitle(String.localized("ok"), for: .normal)
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

    private lazy var infoButton: DynamicFontButton = {
        let view = DynamicFontButton()
        view.setTitle(String.localized("more_info_desktop"), for: .normal)
        view.setTitleColor(.systemBlue, for: .normal)
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
        let view = UIStackView(arrangedSubviews: [infoButton, acceptButton])
        view.axis = .horizontal
        view.distribution = .fillEqually
        view.alignment = .fill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public required init(useDeleteButton: Bool) {
        self.useDeleteButton = useDeleteButton
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
        infoButton.addGestureRecognizer(blockGestureListener)

    }

    @objc func onAcceptPressed() {
        delegate?.onAcceptBrokenProtection()
    }

    @objc func onRejectPressed() {
        delegate?.onBrokenProtectionInfo()
    }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: super.intrinsicContentSize.width, height: 44)
    }
}
