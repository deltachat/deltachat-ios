import UIKit

public class QuoteView: UIView {
    lazy var citeBar: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.clipsToBounds = true
        view.layer.cornerRadius = 1.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public lazy var quote: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        view.text = "quote"
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public lazy var senderTitle: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredFont(for: .caption1, weight: .bold)
        view.text = "title"
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

    func setupSubviews() {
        addSubview(citeBar)
        addSubview(senderTitle)
        addSubview(quote)

        addConstraints([
            senderTitle.constraintAlignTopTo(self, paddingTop: 4),
            senderTitle.constraintAlignLeadingTo(self, paddingLeading: 24),
            senderTitle.constraintAlignTrailingTo(self, paddingTrailing: 4),
            quote.constraintAlignLeadingTo(self, paddingLeading: 24),
            quote.constraintToBottomOf(senderTitle),
            quote.constraintAlignTrailingTo(self, paddingTrailing: 4),
            quote.constraintAlignBottomTo(self, paddingBottom: 4),
            citeBar.constraintAlignLeadingTo(self, paddingLeading: 16),
            citeBar.constraintAlignTopTo(senderTitle, paddingTop: 4),
            citeBar.constraintAlignBottomTo(quote, paddingBottom: 4),
            citeBar.constraintWidthTo(3)
        ])
    }
}
