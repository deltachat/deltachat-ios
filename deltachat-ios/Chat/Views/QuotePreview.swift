import UIKit
import InputBarAccessoryView
import DcCore

public class QuotePreview: DraftPreview {

    public weak var delegate: DraftPreviewDelegate?
    private var compactView = false

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
        quoteView.quote.numberOfLines = 3
    }

    override public func configure(draft: DraftModel) {
        if let quoteText = draft.quoteText {
            quoteView.quote.text = quoteText
            compactView = draft.attachment != nil
            calculateQuoteHeight(compactView: compactView)
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

    func calculateQuoteHeight(compactView: Bool) {
        let vertical = traitCollection.verticalSizeClass == .regular
        if vertical {
            quoteView.quote.numberOfLines = compactView ? 1 : 3
        } else {
            quoteView.quote.numberOfLines = 1
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if (self.traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass)
                || (self.traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass) {
            calculateQuoteHeight(compactView: compactView)
        }
    }
}
