import UIKit
import Combine
import DcCore

public class InitialsBadge: UIView {

    private var boundsPublisher: AnyCancellable?

    var leadingImageAnchorConstraint: NSLayoutConstraint?
    var trailingImageAnchorConstraint: NSLayoutConstraint?
    var topImageAnchorConstraint: NSLayoutConstraint?
    var bottomImageAnchorConstraint: NSLayoutConstraint?

    public var imagePadding: CGFloat = 0 {
        didSet {
            leadingImageAnchorConstraint?.constant = imagePadding
            topImageAnchorConstraint?.constant = imagePadding
            trailingImageAnchorConstraint?.constant = -imagePadding
            bottomImageAnchorConstraint?.constant = -imagePadding
        }
    }

    private var label: UILabel = {
        let label = UILabel()
        label.textAlignment = NSTextAlignment.center
        label.textColor = UIColor.white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = false
        return label
    }()

    private var recentlySeenView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DcColors.recentlySeenDot
        view.clipsToBounds = true
        view.isHidden = true
        return view
    }()

    private var imageView: UIImageView = {
        let imageViewContainer = UIImageView()
        imageViewContainer.clipsToBounds = true
        imageViewContainer.translatesAutoresizingMaskIntoConstraints = false
        return imageViewContainer
    }()
    
    private lazy var unreadMessageCounter: MessageCounter = {
        let view = MessageCounter(count: 0, size: 20)
        view.isHidden = true
        view.isAccessibilityElement = false
        return view
    }()

    public convenience init(name: String, color: UIColor, size: CGFloat, accessibilityLabel: String? = nil) {
        self.init(size: size, accessibilityLabel: accessibilityLabel)
        setName(name)
        setColor(color)
    }

    public convenience init(image: UIImage, size: CGFloat, accessibilityLabel: String? = nil) {
        self.init(size: size, accessibilityLabel: accessibilityLabel)
        setImage(image)
    }

    /// Pass nil to *size* if you want to dynamically resize this view later
    public init(size: CGFloat?, accessibilityLabel: String? = nil) {
        super.init(frame: CGRect(x: 0, y: 0, width: size ?? 0, height: size ?? 0))
        self.accessibilityLabel = accessibilityLabel
        translatesAutoresizingMaskIntoConstraints = false
        if let size {
            heightAnchor.constraint(equalToConstant: size).isActive = true
        }
        widthAnchor.constraint(equalTo: heightAnchor, multiplier: 1).isActive = true
        boundsPublisher = publisher(for: \.bounds).sink { [weak self] bounds in
            guard let self else { return }
            layer.cornerRadius = bounds.width / 2
            imageView.layer.cornerRadius = bounds.width / 2
            label.font = UIFont.systemFont(ofSize: bounds.width * 3 / 5)
            let recentlySeenViewWh = min(35, bounds.height / 2 * 0.6)
            recentlySeenView.frame.size.width = recentlySeenViewWh
            recentlySeenView.frame.size.height = recentlySeenViewWh
            recentlySeenView.layer.cornerRadius = recentlySeenViewWh / 2
        }
        setupSubviews()
        isAccessibilityElement = true
    }

    private func setupSubviews() {
        addSubview(imageView)
        leadingImageAnchorConstraint = imageView.leadingAnchor.constraint(equalTo: leadingAnchor)
        trailingImageAnchorConstraint = imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
        topImageAnchorConstraint = imageView.topAnchor.constraint(equalTo: topAnchor)
        bottomImageAnchorConstraint = imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            leadingImageAnchorConstraint,
            trailingImageAnchorConstraint,
            topImageAnchorConstraint,
            bottomImageAnchorConstraint,
        ].compactMap { $0 })

        addSubview(label)
        label.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        label.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true

        addSubview(recentlySeenView)
        addSubview(unreadMessageCounter)
        NSLayoutConstraint.activate([
            recentlySeenView.bottomAnchor.constraint(equalTo: bottomAnchor),
            recentlySeenView.trailingAnchor.constraint(equalTo: trailingAnchor),
            unreadMessageCounter.topAnchor.constraint(equalTo: topAnchor),
            unreadMessageCounter.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8),
        ])
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setName(_ name: String) {
        label.text = DcUtils.getInitials(inputName: name)
        label.isHidden = name.isEmpty
        imageView.isHidden = !name.isEmpty
    }

    public func setImage(_ image: UIImage?) {
        guard let image else { return }
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

    public func setRecentlySeen(_ seen: Bool) {
        recentlySeenView.isHidden = !seen
    }
    
    public func setUnreadMessageCount(_ messageCount: Int, isMuted: Bool = false) {
        unreadMessageCounter.setCount(messageCount)
        unreadMessageCounter.backgroundColor = isMuted ? DcColors.unreadBadgeMuted : DcColors.unreadBadge
        unreadMessageCounter.isHidden = messageCount == 0
    }

    public func reset() {
        imageView.image = nil
        label.text = nil
        accessibilityLabel = nil
    }

    // render including shape etc.
    public func asImage() -> UIImage {
        UIGraphicsImageRenderer(size: bounds.size).image { _ in
            drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }

    // return the raw, rectange image
    public func getImage() -> UIImage? {
        return imageView.image
    }
}
