import UIKit

class InitialsBadge: UIView {

    private let verificationViewPadding = CGFloat(2)

    private var label: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = NSTextAlignment.center
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
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

    convenience init (image: UIImage, size: CGFloat) {
        self.init(size: size)
        setImage(image)
    }

    convenience init (image: UIImage, size: CGFloat, downscale: CGFloat) {
        self.init(size: size)
        setImage(image, downscale: downscale)
    }

    init(size: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        let radius = size / 2
        layer.cornerRadius = radius
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: size).isActive = true
        widthAnchor.constraint(equalToConstant: size).isActive = true
        setupSubviews(with: radius)
    }

    private func setupSubviews(with radius: CGFloat) {
        addSubview(imageView)
        imageView.layer.cornerRadius = radius
        imageView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        imageView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        imageView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

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
        label.isHidden = false
        imageView.isHidden = true
    }

    func setImage(_ image: UIImage) {
        if let resizedImg = image.resizeImage(targetSize: CGSize(width: self.frame.width, height: self.frame.height)) {
            self.imageView.image = resizedImg
            self.imageView.isHidden = false
            self.label.isHidden = true
        }
    }

    func setImage(_ image: UIImage, downscale: CGFloat) {
        var scale = downscale
        if (scale > 1) {
            scale = 1
        } else if (scale < 0) {
            scale = 0
        }

        if let resizedImg = image.resizeImage(targetSize: CGSize(width: self.frame.width * scale, height: self.frame.height * scale)) {
            self.imageView.image = resizedImg
            self.imageView.contentMode = UIView.ContentMode.center
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
