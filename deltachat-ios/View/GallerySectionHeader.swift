import UIKit
import DcCore

class GalleryGridSectionHeader: UICollectionReusableView {
    static let reuseIdentifier = "gallery_grid_section_header"

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = DcColors.grayTextColor
        return label
    }()

    private lazy var labelTopConstraint: NSLayoutConstraint = {
        return label.topAnchor.constraint(equalTo: topAnchor, constant: 0)
    }()

    private lazy var labelBottomConstraint: NSLayoutConstraint = {
        return label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
    }()

    var leadingMargin: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    var text: String? {
        set {
            label.text = newValue?.uppercased()
            yAlignLabel(ratio: 0.75)
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
        labelTopConstraint.isActive = true
        labelBottomConstraint.isActive = true
        label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingMargin).isActive = true
        label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -leadingMargin).isActive = true
    }

    /// Can be used to offset the label from center (if there is enough space) - ration == 0.5 will Ycenter the label - ratio >= 0.5 will move the label down.
    private func yAlignLabel(ratio: CGFloat) {
        safe_assert(ratio <= 1)
        let labelHeight = label.intrinsicContentSize.height
        let verticalMarginTotal = frame.height - labelHeight
        if verticalMarginTotal > 0 {
            labelBottomConstraint.constant = verticalMarginTotal * (1 - ratio)
            labelTopConstraint.constant = verticalMarginTotal * ratio
        }
    }
}
