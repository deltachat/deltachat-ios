import UIKit
import DcCore

public class WebxdcPreview: UIView {
    
    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?
    
    lazy var imagePreview: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    lazy var titleView: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredBoldFont(for: .body)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 1
        view.lineBreakMode = .byTruncatingTail
        isAccessibilityElement = false
        return view
    }()
    
    lazy var subtitleView: UILabel = {
        let view = UILabel()
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.numberOfLines = 3
        isAccessibilityElement = false
        return view
    }()
    
    lazy var containerStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [imagePreview, titleView, subtitleView])
        view.axis = .vertical
        view.spacing = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    convenience init() {
        self.init(frame: .zero)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubviews()
    }
    
    private func setupSubviews() {
        addSubview(containerStackView)
        containerStackView.fillSuperview()
        imageWidthConstraint = imagePreview.constraintWidthTo(80)
        imageHeightConstraint = imagePreview.constraintHeightTo(80, priority: .defaultLow)
    }
    
    public func configure(message: DcMsg) {
        imagePreview.image = message.getWebxdcIcon()
        titleView.text = message.getWebxdcName()
        subtitleView.text = message.getWebxdcSummary()
    }

    public func configureAccessibilityLabel() -> String {
        var accessibilityTitle = ""
        var accessiblitySubtitle = ""
        if let titleText = titleView.text {
            accessibilityTitle = titleText
        }
        if let subtitleText = subtitleView.text {
            accessiblitySubtitle = subtitleText
        }
        
        return "\(accessibilityTitle), \(accessiblitySubtitle)"
    }

    public func prepareForReuse() {
        imagePreview.image = nil
    }
    
}
