import UIKit
import DcCore

class GalleryTimeLabel: UIView {

    private lazy var label: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()

    init() {
        super.init(frame: .zero)
        setupSubviews()
        backgroundColor = DcColors.primary.withAlphaComponent(0.8)
        layer.cornerRadius = 4
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8).isActive = true
        label.topAnchor.constraint(equalTo: topAnchor, constant: 2).isActive = true
        label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8).isActive = true
        label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2).isActive = true
    }

    func update(date: Date) {
        let localizedDescription = date.galleryLocalizedDescription
        if label.text != localizedDescription {
            label.text = localizedDescription
        }
    }

    func show(animated: Bool) {
        UIView.animate(withDuration: animated ? 0.2 : 0) {
            self.alpha = 1
        }
    }

    func hide(animated: Bool) {
        UIView.animate(withDuration: animated ? 0.2 : 0, delay: animated ? 0.2 : 0, options: .curveEaseInOut, animations: {
            self.alpha = 0
        })
    }
}
