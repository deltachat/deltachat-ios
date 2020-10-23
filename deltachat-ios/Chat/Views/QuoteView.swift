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

    lazy var quote: PaddingTextView = {
        let view = PaddingTextView()
        view.font = UIFont.preferredFont(for: .caption1, weight: .regular)
        view.text = "quote"
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
        addSubview(quote)

        quote.paddingTop = 4
        quote.paddingBottom = 4
        quote.paddingLeading = 4
        quote.paddingTrailing = 4
        addConstraints([
            quote.constraintAlignLeadingTo(self, paddingLeading: 20),
            quote.constraintAlignTopTo(self),
            quote.constraintAlignTrailingTo(self),
            quote.constraintAlignBottomTo(self),
            citeBar.constraintAlignLeadingTo(self, paddingLeading: 16),
            citeBar.constraintAlignTopTo(quote, paddingTop: 4),
            citeBar.constraintAlignBottomTo(quote, paddingBottom: 4),
            citeBar.constraintWidthTo(3)
        ])
    }
}
