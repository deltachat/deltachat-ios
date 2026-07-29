import Foundation
import UIKit

open class AudioPlayerView: UIView {

    private var durationCenterYConstraint: NSLayoutConstraint?
    private var durationBottomConstraint: NSLayoutConstraint?
    private var playbackControlsAreVisible = false
    private let durationLabelCompactTransform = CGAffineTransform(scaleX: 0.9, y: 0.9)
    private let speedButtonHiddenTransform = CGAffineTransform(translationX: 0, y: 11.04).scaledBy(x: 1, y: 0.08)

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
        let font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .bold)
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
        button.isHidden = true
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
        playButton.constraintHeightTo(45, priority: UILayoutPriority(rawValue: 999)).isActive = true
        playButton.constraintWidthTo(45, priority: UILayoutPriority(rawValue: 999)).isActive = true
        durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        trailingControlsView.widthAnchor.constraint(equalTo: durationLabel.widthAnchor).isActive = true
        trackContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true

        let playButtonConstraints = [playButton.constraintCenterYTo(self),
                                     playButton.constraintAlignLeadingTo(self, paddingLeading: 12)]
        let trackContainerConstraints = [trackContainerView.leftAnchor.constraint(equalTo: playButton.rightAnchor, constant: 8),
                                         trackContainerView.rightAnchor.constraint(equalTo: trailingControlsView.leftAnchor, constant: -4),
                                         trackContainerView.topAnchor.constraint(equalTo: topAnchor),
                                         trackContainerView.bottomAnchor.constraint(equalTo: bottomAnchor)]
        let trailingControlsConstraints = [trailingControlsView.constraintAlignTrailingTo(self, paddingTrailing: 12),
                                           trailingControlsView.topAnchor.constraint(equalTo: topAnchor),
                                           trailingControlsView.bottomAnchor.constraint(equalTo: bottomAnchor)]
        durationCenterYConstraint = durationLabel.centerYAnchor.constraint(equalTo: trailingControlsView.centerYAnchor)
        durationBottomConstraint = durationLabel.bottomAnchor.constraint(equalTo: trailingControlsView.bottomAnchor)
        let durationLabelConstraints = [durationLabel.centerXAnchor.constraint(equalTo: trailingControlsView.centerXAnchor),
                                        durationCenterYConstraint!]
        self.addConstraints(playButtonConstraints)
        self.addConstraints(trackContainerConstraints)
        self.addConstraints(trailingControlsConstraints)
        self.addConstraints(durationLabelConstraints)

        NSLayoutConstraint.activate([
            speedButton.centerXAnchor.constraint(equalTo: trailingControlsView.centerXAnchor),
            speedButton.topAnchor.constraint(equalTo: trailingControlsView.topAnchor),
            speedButton.widthAnchor.constraint(equalToConstant: 50),
            speedButton.heightAnchor.constraint(equalToConstant: 24),
            progressBar.leftAnchor.constraint(equalTo: trackContainerView.leftAnchor),
            progressBar.rightAnchor.constraint(equalTo: trackContainerView.rightAnchor),
            progressBar.centerYAnchor.constraint(equalTo: trackContainerView.centerYAnchor)
        ])
        let height = self.heightAnchor.constraint(equalTo: playButton.heightAnchor)
        height.priority = .required
        height.isActive = true
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

    open func showPlayLayout(_ play: Bool) {
        playButton.isSelected = play
        playButton.accessibilityLabel = play ? String.localized("menu_pause") : String.localized("menu_play")
        speedButton.isAccessibilityElement = play
        setPlaybackControlsLayout(isPlaying: play, animated: true)
    }

    func setPlaybackRateLabel(_ rateLabel: String) {
        speedButton.setTitle(rateLabel, for: .normal)
        speedButton.accessibilityValue = rateLabel
    }

    private func setPlaybackControlsLayout(isPlaying: Bool, animated: Bool) {
        playbackControlsAreVisible = isPlaying
        let wasHidden = speedButton.isHidden
        durationCenterYConstraint?.isActive = !isPlaying
        durationBottomConstraint?.isActive = isPlaying

        if wasHidden {
            speedButton.transform = speedButtonHiddenTransform
        }
        if isPlaying {
            speedButton.isHidden = false
        }

        let speedButtonTitleAlpha: CGFloat = isPlaying ? 1 : 0

        guard animated else {
            self.layoutIfNeeded()
            speedButton.isHidden = !isPlaying
            speedButton.transform = isPlaying ? .identity : speedButtonHiddenTransform
            durationLabel.transform = isPlaying ? durationLabelCompactTransform : .identity
            speedButton.titleLabel?.alpha = speedButtonTitleAlpha
            return
        }

        UIView.animateKeyframes(withDuration: 0.36,
                                delay: 0,
                                options: [.beginFromCurrentState, .allowUserInteraction, .calculationModeCubic],
                                animations: {
            if isPlaying {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25, animations: {
                    self.durationLabel.transform = self.durationLabelCompactTransform
                })
                UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.75, animations: {
                    self.speedButton.transform = .identity
                    self.layoutIfNeeded()
                    self.speedButton.titleLabel?.alpha = speedButtonTitleAlpha
                })
            } else {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.55, animations: {
                    self.speedButton.titleLabel?.alpha = speedButtonTitleAlpha
                    self.speedButton.transform = CGAffineTransform(translationX: 0, y: 12).scaledBy(x: 1, y: 0)
                })
                UIView.addKeyframe(withRelativeStartTime: 0.55, relativeDuration: 0.45, animations: {
                    self.layoutIfNeeded()
                    self.durationLabel.transform = .identity
                })
            }
        }, completion: { finished in
            if finished, !self.playbackControlsAreVisible {
                self.speedButton.isHidden = true
            }
        })
    }
}
