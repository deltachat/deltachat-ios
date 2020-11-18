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

    lazy var cancelButton: UIImageView = {
        let view = UIImageView(image: UIImage(named: "ic_close_36pt"))
        view.tintColor = .darkGray
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()

    lazy var upperBorder: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.lightGray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public var text: String? {
        set { quoteView.quote.text = newValue }
        get { return quoteView.quote.text }
    }

    public var senderTitle: UILabel {
        set { quoteView.senderTitle = newValue }
        get { return quoteView.senderTitle }
    }

    public var citeBar: UIView {
        set { quoteView.citeBar = newValue }
        get { return quoteView.citeBar }
    }

    public var imagePreview: UIImageView {
        set { quoteView.imagePreview = newValue }
        get { return quoteView.imagePreview }
    }

    init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupSubviews() {
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
            cancelButton.constraintWidthTo(30),
            cancelButton.constraintHeightTo(30),
            cancelButton.constraintCenterYTo(self),
        ])
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(onCancelPressed))
        cancelButton.addGestureRecognizer(recognizer)
    }

    @objc func onCancelPressed() {
        quoteView.prepareForReuse()
        delegate?.onCancel()
    }
}
