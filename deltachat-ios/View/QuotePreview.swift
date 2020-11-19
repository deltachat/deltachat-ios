import UIKit
import InputBarAccessoryView
import DcCore

public protocol QuotePreviewDelegate: class {
    func onCancel()
}

public class QuotePreview: UIView, InputItem {
    
    public var inputBarAccessoryView: InputBarAccessoryView?
    public var parentStackViewPosition: InputStackView.Position?
    public func textViewDidChangeAction(with textView: InputTextView) {}
    public func keyboardSwipeGestureAction(with gesture: UISwipeGestureRecognizer) {}
    public func keyboardEditingEndsAction() {}
    public func keyboardEditingBeginsAction() {}

    public weak var delegate: QuotePreviewDelegate?

    lazy var quoteView: QuoteView = {
        let view = QuoteView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    lazy var cancelButton: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelImageView)
        return view
    }()

    private lazy var cancelImageView: UIImageView = {
        let view = UIImageView(image: UIImage(named: "ic_close_36pt"))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var upperBorder: UIView = {
        let view = UIView()
        view.backgroundColor = DcColors.colorDisabled
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(upperBorder)
        addSubview(quoteView)
        addSubview(cancelButton)
        addConstraints([
            upperBorder.constraintAlignLeadingTo(self),
            upperBorder.constraintAlignTrailingTo(self),
            upperBorder.constraintHeightTo(1),
            upperBorder.constraintAlignTopTo(self, paddingTop: 4),
            quoteView.constraintAlignTopTo(upperBorder, paddingTop: 4),
            quoteView.constraintAlignLeadingTo(self),
            quoteView.constraintAlignBottomTo(self, paddingBottom: 4),
            quoteView.constraintTrailingToLeadingOf(cancelButton),
            cancelButton.constraintAlignTrailingTo(self, paddingTrailing: 8),
            cancelButton.constraintWidthTo(35),
            cancelButton.constraintHeightTo(35),
            cancelImageView.constraintAlignLeadingTo(cancelButton, paddingLeading: 5),
            cancelImageView.constraintAlignTrailingTo(cancelButton, paddingTrailing: 5),
            cancelImageView.constraintAlignTopTo(cancelButton, paddingTop: 5),
            cancelImageView.constraintAlignBottomTo(cancelButton, paddingBottom: 5),
            cancelButton.constraintCenterYTo(self),
        ])
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(cancel))
        cancelButton.addGestureRecognizer(recognizer)
    }

    @objc public func cancel() {
        quoteView.prepareForReuse()
        delegate?.onCancel()
    }

    public func configure(draft: DraftModel) {
        if draft.quoteMessage == nil && draft.quoteText == nil {
            isHidden = true
            return
        }
        quoteView.quote.text = draft.quoteText ?? draft.quoteMessage?.summary(chars: 80)
        if let quoteMessage = draft.quoteMessage {
            let contact = quoteMessage.fromContact
            quoteView.senderTitle.text = contact.displayName
            quoteView.senderTitle.textColor = contact.color
            quoteView.citeBar.backgroundColor = contact.color
            quoteView.imagePreview.image = quoteMessage.image
        }
        isHidden = false
    }
}
