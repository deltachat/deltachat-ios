import UIKit

class InitialsBadge: UIView {

    private let verificationViewPadding: CGFloat = 2
    private let size: CGFloat

    private var label: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
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

    convenience init(name: String, color: UIColor, size: CGFloat) {
        self.init(size: size)
        setName(name)
        setColor(color)
    }

    convenience init (image: UIImage, size: CGFloat, downscale: CGFloat? = nil) {
        self.init(size: size)
        setImage(image, downscale: downscale)
    }

    init(size: CGFloat) {
        self.size = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
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

    func setName(_ name: String) {
        label.text = Utils.getInitials(inputName: name)
        label.isHidden = name.isEmpty
        imageView.isHidden = !name.isEmpty
        accessibilityLabel = "avatar \(name)"
    }

    func setImage(_ image: UIImage, downscale: CGFloat? = nil) {
        var scale = downscale ?? 1
        if scale > 1 {
            scale = 1
        } else if scale < 0 {
            scale = 0
        }

        if let resizedImg = image.scaleDownImage(toMax: self.size * scale) {
            self.imageView.image = resizedImg
            self.imageView.contentMode = (downscale == nil) ? UIView.ContentMode.scaleAspectFill : UIView.ContentMode.center
            self.imageView.isHidden = false
            self.label.isHidden = true
        }
    }

    func showsInitials() -> Bool {
        return !label.isHidden
    }

    func setColor(_ color: UIColor) {
        backgroundColor = color
    }

    func setVerified(_ verified: Bool) {
        verifiedView.isHidden = !verified
    }
}
