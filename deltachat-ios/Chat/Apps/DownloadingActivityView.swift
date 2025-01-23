import UIKit

class DownloadingView: UIView {
    let activityIndicator: UIActivityIndicatorView
    private let blurView: UIVisualEffectView

    init() {
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .label
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 10
        blurView.layer.masksToBounds = true

        super.init(frame: .zero)

        addSubview(blurView)
        addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            activityIndicator.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 20),
            activityIndicator.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 20),
            blurView.trailingAnchor.constraint(equalTo: activityIndicator.trailingAnchor, constant: 20),
            blurView.bottomAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
