import UIKit
import DcCore

class GalleryGridSectionHeader: UICollectionReusableView {
    static let reuseIdentifier = "gallery_grid_section_header"

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = DcColors.grayTextColor
        return label
    }()

    var leadingMargin: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    var text: String? {
        set {
            label.text = newValue?.uppercased()
        }
        get {
            return label.text
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        backgroundColor = .white
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingMargin).isActive = true
        label.topAnchor.constraint(equalTo: topAnchor, constant: 0).isActive = true
        label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -leadingMargin).isActive = true
        label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
    }
}
