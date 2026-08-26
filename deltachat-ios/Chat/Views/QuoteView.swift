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

        NSLayoutConstraint.activate([
            imagePreview.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            imagePreview.heightAnchor.constraint(equalToConstant: 36),
            imagePreview.centerYAnchor.constraint(equalTo: citeBar.centerYAnchor),
            imagePreview.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            senderTitle.topAnchor.constraint(equalTo: topAnchor),
            senderTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            senderTitle.trailingAnchor.constraint(equalTo: imagePreview.leadingAnchor, constant: -8),
            quote.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            quote.topAnchor.constraint(equalTo: senderTitle.bottomAnchor),
            quote.trailingAnchor.constraint(equalTo: imagePreview.leadingAnchor, constant: -8),
            quote.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            citeBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            citeBar.topAnchor.constraint(equalTo: senderTitle.topAnchor, constant: 2),
            citeBar.bottomAnchor.constraint(equalTo: quote.bottomAnchor, constant: -2),
            citeBar.widthAnchor.constraint(equalToConstant: 3),
        ])
        let widthConstraint = imagePreview.widthAnchor.constraint(equalToConstant: 0)
        imageWidthConstraint = widthConstraint
        widthConstraint.isActive = true
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
