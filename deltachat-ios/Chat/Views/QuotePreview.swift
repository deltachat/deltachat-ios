import UIKit
import InputBarAccessoryView
import DcCore

public class QuotePreview: DraftPreview {

    public weak var delegate: DraftPreviewDelegate?

    lazy var quoteView: QuoteView = {
        let view = QuoteView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addSubview(quoteView)
        quoteView.fillSuperview()
    }

    override public func cancel() {
        quoteView.prepareForReuse()
        delegate?.onCancelQuote()
    }

    override public func configure(draft: DraftModel) {
        if let quoteText = draft.quoteText {
            quoteView.quote.text = quoteText
            if let quoteMessage = draft.quoteMessage {
                let contact = quoteMessage.fromContact
                quoteView.senderTitle.text = contact.displayName
                quoteView.senderTitle.textColor = contact.color
                quoteView.citeBar.backgroundColor = contact.color
                quoteView.imagePreview.image = quoteMessage.image
            }
            isHidden = false
        } else {
            isHidden = true
        }
    }
}
