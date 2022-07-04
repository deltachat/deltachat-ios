import UIKit
import DcCore

public class QuoteView: UIView {
    public lazy var citeBar: UIView = {
        let view = UIView()
        view.backgroundColor = DcColors.unknownSender
        view.clipsToBounds = true
        view.layer.cornerRadius = 1.5
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = false
        return view
    }()

    public lazy var quote: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredFont(for: .subheadline, weight: .regular)
        view.textColor = DcColors.grayTextColor
        view.numberOfLines = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = false
        return view
    }()

    public lazy var senderTitle: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredFont(for: .caption1, weight: .semibold)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = false
        return view
    }()

    private lazy var imagePreview: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isAccessibilityElement = false
        return view
    }()

    private var imageWidthConstraint: NSLayoutConstraint?

    init() {
        super.init(frame: .zero)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        isAccessibilityElement = true
        addSubview(citeBar)
        addSubview(senderTitle)
        addSubview(imagePreview)
        addSubview(quote)

        addConstraints([
            imagePreview.constraintAlignTrailingTo(self, paddingTrailing: 16),
            imagePreview.constraintHeightTo(36),
            imagePreview.constraintCenterYTo(citeBar),
            imagePreview.constraintAlignTopMaxTo(self),
            senderTitle.constraintAlignTopTo(self),
            senderTitle.constraintAlignLeadingTo(self, paddingLeading: 28),
            senderTitle.constraintTrailingToLeadingOf(imagePreview, paddingTrailing: 8),
            quote.constraintAlignLeadingTo(self, paddingLeading: 28),
            quote.constraintToBottomOf(senderTitle),
            quote.constraintTrailingToLeadingOf(imagePreview, paddingTrailing: 8),
            quote.constraintAlignBottomTo(self, paddingBottom: 4),
            citeBar.constraintAlignLeadingTo(self, paddingLeading: 14),
            citeBar.constraintAlignTopTo(senderTitle, paddingTop: 2),
            citeBar.constraintAlignBottomTo(quote, paddingBottom: 2),
            citeBar.constraintWidthTo(3),
        ])
        imageWidthConstraint = imagePreview.constraintWidthTo(0)
        imageWidthConstraint?.isActive = true
    }

    public func configureAccessibilityLabel() -> String {
        var accessibilitySenderTitle = ""
        var accessibilityQuoteText = ""
        var accessibilityQuoteImageText = ""
        if let senderTiteText = senderTitle.text {
            accessibilitySenderTitle = "\(senderTiteText), "
        }
        if let quoteText = quote.text {
            accessibilityQuoteText = "\(quoteText), "
        }
        if imagePreview.image != nil {
            accessibilityQuoteImageText = "\(String.localized("image")), "
        }
        return "\(accessibilitySenderTitle), \(accessibilityQuoteText), \(accessibilityQuoteImageText)"
    }

    public func prepareForReuse() {
        quote.text = nil
        quote.attributedText = nil
        senderTitle.text = nil
        senderTitle.attributedText = nil
        citeBar.backgroundColor = DcColors.unknownSender
        imagePreview.image = nil
        imageWidthConstraint?.constant = 0
    }

    public func setImagePreview(_ image: UIImage?) {
        if let image = image {
            imageWidthConstraint?.constant = 36
            imagePreview.image = image
        } else {
            imageWidthConstraint?.constant = 0
        }
    }

    public func setRoundedCorners(_ isRounded: Bool) {
        imagePreview.layer.cornerRadius = isRounded ? 4 : 0
    }
}
