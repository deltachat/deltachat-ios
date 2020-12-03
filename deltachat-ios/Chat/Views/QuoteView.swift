import UIKit
import DcCore

public class QuoteView: UIView {
    public lazy var citeBar: UIView = {
        let view = UIView()
        view.backgroundColor = DcColors.grayDateColor
        view.clipsToBounds = true
        view.layer.cornerRadius = 1.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public lazy var quote: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredFont(for: .subheadline, weight: .regular)
        view.textColor = DcColors.grayTextColor
        view.numberOfLines = 3
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public lazy var senderTitle: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredFont(for: .caption1, weight: .semibold)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public lazy var imagePreview: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
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
        addSubview(citeBar)
        addSubview(senderTitle)
        addSubview(imagePreview)
        addSubview(quote)

        addConstraints([
            imagePreview.constraintAlignTrailingTo(self, paddingTrailing: 16),
            imagePreview.constraintHeightTo(36),
            imagePreview.constraintWidthTo(36),
            imagePreview.constraintCenterYTo(citeBar),
            imagePreview.constraintAlignTopMaxTo(self),
            senderTitle.constraintAlignTopTo(self),
            senderTitle.constraintAlignLeadingTo(self, paddingLeading: 28),
            senderTitle.constraintTrailingToLeadingOf(imagePreview, paddingTrailing: 8),
            quote.constraintAlignLeadingTo(self, paddingLeading: 28),
            quote.constraintToBottomOf(senderTitle),
            quote.constraintTrailingToLeadingOf(imagePreview, paddingTrailing: 8),
            quote.constraintAlignBottomTo(self, paddingBottom: 4),
            citeBar.constraintAlignLeadingTo(self, paddingLeading: 16),
            citeBar.constraintAlignTopTo(senderTitle, paddingTop: 2),
            citeBar.constraintAlignBottomTo(quote, paddingBottom: 2),
            citeBar.constraintWidthTo(3),
        ])
    }

    public func prepareForReuse() {
        quote.text = nil
        quote.attributedText = nil
        senderTitle.text = nil
        senderTitle.attributedText = nil
        citeBar.backgroundColor = DcColors.grayDateColor
        imagePreview.image = nil
    }
}
