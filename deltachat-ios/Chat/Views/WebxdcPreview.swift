import UIKit
import DcCore

public class WebxdcPreview: UIView {
    
    lazy var imagePreview: UIImageView = {
        let view = UIImageView()
        view.contentMode = .left
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
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
        view.numberOfLines = 1
        view.lineBreakMode = .byTruncatingTail
        isAccessibilityElement = false
        return view
    }()
    
    lazy var containerStackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [imagePreview, titleView, subtitleView])
        view.axis = .vertical
        view.alignment = .leading
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
    }
    
    public func configure(message: DcMsg) {
        let dict = message.getWebxdcInfoDict()
        if let iconfilePath = dict["icon"] as? String {
            let blob = message.getWebxdcBlob(filename: iconfilePath)
            if !blob.isEmpty {
                imagePreview.image = UIImage(data: blob)?.sd_resizedImage(with: CGSize(width: 175, height: 175), scaleMode: .aspectFill)
            }
        }
        titleView.text = dict["name"] as? String
        guard let summary = dict["summary"] as? String, !summary.isEmpty else {
            subtitleView.text = "Webxdc"
            return
        }
        subtitleView.text = summary
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
