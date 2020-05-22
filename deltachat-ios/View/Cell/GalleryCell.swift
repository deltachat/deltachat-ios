import UIKit
import DcCore

class GalleryCell: UICollectionViewCell {
    static let reuseIdentifier = "gallery_cell"

    var imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0).isActive = true
        imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0).isActive = true
        imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
        imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0).isActive = true
    }

    func update(msg: DcMsg) {
        guard let image = msg.image else {
            return
        }
        imageView.image = image
    }

    override var isSelected: Bool {
        willSet {
            contentView.backgroundColor = newValue ? DcColors.primary : .white
            imageView.alpha = newValue ? 0.75 : 1.0
        }
    }
}
