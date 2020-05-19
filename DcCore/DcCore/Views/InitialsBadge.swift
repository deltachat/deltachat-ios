import UIKit

public class InitialsBadge: UIView {

    private let verificationViewPadding: CGFloat = 2
    private let size: CGFloat

    private var label: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 26)
        label.textAlignment = NSTextAlignment.center
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = false
        return label
    }()

    private var verifiedView: UIImageView = {
        let imgView = UIImageView()
        let img = UIImage(named: "verified")
        imgView.isHidden = true
        imgView.image = img
        imgView.translatesAutoresizingMaskIntoConstraints = false
        return imgView
    }()

    private var imageView: UIImageView = {
        let imageViewContainer = UIImageView()
        imageViewContainer.clipsToBounds = true
        imageViewContainer.translatesAutoresizingMaskIntoConstraints = false
        return imageViewContainer
    }()

    public var cornerRadius: CGFloat {
        set {
            layer.cornerRadius = newValue
            imageView.layer.cornerRadius = newValue
        }
        get {
            return layer.cornerRadius
        }
    }

    public convenience init(name: String, color: UIColor, size: CGFloat, accessibilityLabel: String? = nil) {
        self.init(size: size, accessibilityLabel: accessibilityLabel)
        setName(name)
        setColor(color)
    }


    public convenience init (image: UIImage, size: CGFloat, accessibilityLabel: String? = nil) {
        self.init(size: size, accessibilityLabel: accessibilityLabel)
        setImage(image)
    }

    public init(size: CGFloat, accessibilityLabel: String? = nil) {
        self.size = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        self.accessibilityLabel = accessibilityLabel
        let radius = size / 2
        layer.cornerRadius = radius
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: size).isActive = true
        widthAnchor.constraint(equalToConstant: size).isActive = true
        setupSubviews(with: radius)
        isAccessibilityElement = true
    }

    private func setupSubviews(with radius: CGFloat) {
        addSubview(imageView)
        imageView.layer.cornerRadius = radius
        imageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        imageView.alignTopToAnchor(topAnchor)
        imageView.alignBottomToAnchor(bottomAnchor)

        addSubview(label)
        label.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        label.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        addSubview(verifiedView)
        let imgViewConstraints = [verifiedView.constraintAlignBottomTo(self, paddingBottom: -verificationViewPadding),
                                  verifiedView.constraintAlignTrailingTo(self, paddingTrailing: -verificationViewPadding),
                                  verifiedView.constraintAlignTopTo(self, paddingTop: radius + verificationViewPadding),
                                  verifiedView.constraintAlignLeadingTo(self, paddingLeading: radius + verificationViewPadding)]
        addConstraints(imgViewConstraints)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setName(_ name: String) {
        label.text = DcUtils.getInitials(inputName: name)
        label.isHidden = name.isEmpty
        imageView.isHidden = !name.isEmpty
    }

    public func setLabelFont(_ font: UIFont) {
        label.font = font
    }

    public func setImage(_ image: UIImage) {
        self.imageView.image = image
        self.imageView.contentMode = UIView.ContentMode.scaleAspectFill
        self.imageView.isHidden = false
        self.label.isHidden = true
    }

    public func showsInitials() -> Bool {
        return !label.isHidden
    }

    public func setColor(_ color: UIColor) {
        backgroundColor = color
    }

    public func setVerified(_ verified: Bool) {
        verifiedView.isHidden = !verified
    }

    public func reset() {
        verifiedView.isHidden = true
        imageView.image = nil
        label.text = nil
    }
}
