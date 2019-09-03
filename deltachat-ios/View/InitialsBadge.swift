import UIKit

class InitialsBadge: UIView {

    private var label: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = NSTextAlignment.center
        label.textColor = UIColor.white
        return label
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

    init(size: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        let initialsLabelCornerRadius = size / 2
        layer.cornerRadius = initialsLabelCornerRadius
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: size).isActive = true
        widthAnchor.constraint(equalToConstant: size).isActive = true
        clipsToBounds = true
        setupSubviews()
    }

    private func setupSubviews() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2).isActive = true
        label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setName(_ name: String) {
        label.text = Utils.getInitials(inputName: name)
    }

    func setImage(_ image: UIImage) {
        let attachment = NSTextAttachment()
        attachment.image = image
        label.attributedText = NSAttributedString(attachment: attachment)
    }

    func setColor(_ color: UIColor) {
        backgroundColor = color
    }
}
