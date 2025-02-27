import UIKit
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
        accessibilityLabel = nil
    }

    override public func configure(draft: DraftModel) {
        if !draft.isEditing, let sendEditRequestFor = draft.sendEditRequestFor {
            quoteView.senderTitle.text = String.localized("edit_message")
            quoteView.senderTitle.textColor = DcColors.unknownSender
            quoteView.quote.text = draft.dcContext.getMessage(id: sendEditRequestFor).text
            quoteView.setImagePreview(nil)
            quoteView.citeBar.backgroundColor = DcColors.unknownSender
            isHidden = false
        } else if !draft.isEditing,
           let quoteText = draft.quoteText {
            quoteView.quote.text = quoteText
            compactView = draft.attachment != nil
            calculateQuoteHeight(compactView: compactView)
            if let quoteMessage = draft.quoteMessage {
                let isWebxdc = quoteMessage.type == DC_MSG_WEBXDC
                let quoteImage = isWebxdc ? quoteMessage.getWebxdcPreviewImage() : quoteMessage.image
                quoteView.setImagePreview(quoteImage)
                quoteView.setRoundedCorners(isWebxdc)
                if quoteMessage.isForwarded {
                    quoteView.senderTitle.text = String.localized("forwarded_message")
                    quoteView.senderTitle.textColor = DcColors.unknownSender
                    quoteView.citeBar.backgroundColor = DcColors.unknownSender
                } else {
                    let contact = draft.dcContext.getContact(id: quoteMessage.fromContactId)
                    quoteView.senderTitle.text = quoteMessage.getSenderName(contact, markOverride: true)
                    quoteView.senderTitle.textColor = contact.color
                    quoteView.citeBar.backgroundColor = contact.color

                }
            }
            accessibilityLabel = quoteView.configureAccessibilityLabel()

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
