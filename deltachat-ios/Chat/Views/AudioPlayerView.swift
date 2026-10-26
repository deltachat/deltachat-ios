import Foundation
import UIKit

open class AudioPlayerView: UIView {

    private var durationCenterYConstraint: NSLayoutConstraint?
    private var durationBottomConstraint: NSLayoutConstraint?
    private let durationLabelCompactTransform = CGAffineTransform(scaleX: 0.9, y: 0.9)
    private let speedButtonHiddenTransform = CGAffineTransform(translationX: 0, y: 6).scaledBy(x: 0.7, y: 0.7)

    /// The play button view to display on audio messages.
    lazy var playButton: UIButton = {
        let playButton = UIButton(type: .custom)
        let playImage = UIImage(named: "play")
        playImage?.isAccessibilityElement = false
        let pauseImage = UIImage(named: "pause")
        pauseImage?.isAccessibilityElement = false
        playButton.setImage(playImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        playButton.setImage(pauseImage?.withRenderingMode(.alwaysTemplate), for: .selected)
        playButton.imageView?.contentMode = .scaleAspectFit
        playButton.contentVerticalAlignment = .fill
        playButton.contentHorizontalAlignment = .fill
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.isUserInteractionEnabled = true
        playButton.accessibilityLabel = String.localized("menu_play")
        return playButton
    }()

    /// The time duration label to display on audio messages.
    private lazy var durationLabel: UILabel = {
        let durationLabel = UILabel(frame: CGRect.zero)
        durationLabel.textAlignment = .center
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let size = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traits).pointSize
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
        durationLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: font)
        durationLabel.adjustsFontForContentSizeCategory = true
        durationLabel.text = "0:00"
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.isAccessibilityElement = false
        return durationLabel
    }()

    lazy var speedButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.preferredFont(for: .caption1, weight: .bold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alpha = 0
        // TODO: Add accessibility label for playback speed.
        button.backgroundColor = .secondarySystemFill
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        return button
    }()

    private lazy var trackContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var trailingControlsView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var progressBar: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.progress = 0.0
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = false
        return view
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.translatesAutoresizingMaskIntoConstraints = false
        setupSubviews()
    }

    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        NSLayoutConstraint.activate([
            playButton.heightAnchor.constraint(equalToConstant: 45).withPriority(UILayoutPriority(rawValue: 999)),
            playButton.widthAnchor.constraint(equalToConstant: 45).withPriority(UILayoutPriority(rawValue: 999)),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            trailingControlsView.widthAnchor.constraint(equalTo: durationLabel.widthAnchor),
            trackContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])

        durationCenterYConstraint = durationLabel.centerYAnchor.constraint(equalTo: trailingControlsView.centerYAnchor)
        durationBottomConstraint = durationLabel.bottomAnchor.constraint(equalTo: trailingControlsView.bottomAnchor)

        NSLayoutConstraint.activate([
            // Track container
            trackContainerView.leftAnchor.constraint(equalTo: playButton.rightAnchor, constant: 8),
            trackContainerView.rightAnchor.constraint(equalTo: trailingControlsView.leftAnchor, constant: -4),
            trackContainerView.topAnchor.constraint(equalTo: topAnchor),
            trackContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Trailing controls
            trailingControlsView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            trailingControlsView.topAnchor.constraint(equalTo: topAnchor),
            trailingControlsView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Duration label
            durationLabel.centerXAnchor.constraint(equalTo: trailingControlsView.centerXAnchor),
            durationCenterYConstraint,
        ].compactMap { $0 })

        NSLayoutConstraint.activate([
            speedButton.centerXAnchor.constraint(equalTo: trailingControlsView.centerXAnchor),
            speedButton.topAnchor.constraint(equalTo: trailingControlsView.topAnchor),
            speedButton.widthAnchor.constraint(equalToConstant: 50),
            speedButton.heightAnchor.constraint(equalToConstant: 24),
            progressBar.leftAnchor.constraint(equalTo: trackContainerView.leftAnchor),
            progressBar.rightAnchor.constraint(equalTo: trackContainerView.rightAnchor),
            progressBar.centerYAnchor.constraint(equalTo: trackContainerView.centerYAnchor),
            heightAnchor.constraint(equalTo: playButton.heightAnchor),
        ])
    }

    open func setupSubviews() {
        self.addSubview(playButton)
        self.addSubview(trackContainerView)
        self.addSubview(trailingControlsView)
        trailingControlsView.addSubview(speedButton)
        trailingControlsView.addSubview(durationLabel)
        trackContainerView.addSubview(progressBar)
        setupConstraints()
        setPlaybackRateLabel("1x")
        setPlaybackControlsLayout(isPlaying: false, animated: false)
    }

    open func reset() {
        setProgress(0)
        playButton.isSelected = false
        durationLabel.text = "0:00"
        playButton.accessibilityLabel = String.localized("menu_play")
        speedButton.isAccessibilityElement = false
        setPlaybackControlsLayout(isPlaying: false, animated: false)
        setPlaybackRateLabel("1x")
    }

    open func setProgress(_ progress: Float) {
        progressBar.progress = progress
    }

    open func setDuration(duration: Double) {
        durationLabel.text = String.timeStringForInterval(duration.rounded(.up))
    }

    open func showPlayLayout(_ play: Bool, animated: Bool = true) {
        playButton.isSelected = play
        playButton.accessibilityLabel = play ? String.localized("menu_pause") : String.localized("menu_play")
        speedButton.isAccessibilityElement = play
        setPlaybackControlsLayout(isPlaying: play, animated: animated)
    }

    func setPlaybackRateLabel(_ rateLabel: String, animated: Bool = false) {
        speedButton.setTitle(rateLabel, for: .normal)
        speedButton.accessibilityValue = rateLabel

        guard animated, !UIAccessibility.isReduceMotionEnabled, speedButton.alpha > 0 else { return }

        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1, 1.08, 1]
        bounce.keyTimes = [0, 0.45, 1]
        bounce.duration = 0.2
        bounce.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut),
                                  CAMediaTimingFunction(name: .easeInEaseOut)]
        speedButton.layer.add(bounce, forKey: "playbackSpeedBounce")
    }

    private func setPlaybackControlsLayout(isPlaying: Bool, animated: Bool) {
        layoutIfNeeded()
        durationCenterYConstraint?.isActive = !isPlaying
        durationBottomConstraint?.isActive = isPlaying
        speedButton.isUserInteractionEnabled = isPlaying

        let changes = {
            self.speedButton.alpha = isPlaying ? 1 : 0
            self.speedButton.transform = isPlaying ? .identity : self.speedButtonHiddenTransform
            self.durationLabel.transform = isPlaying ? self.durationLabelCompactTransform : .identity
            self.layoutIfNeeded()
        }

        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            speedButton.layer.removeAllAnimations()
            durationLabel.layer.removeAllAnimations()
            UIView.performWithoutAnimation(changes)
            return
        }

        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: changes)
    }
}
