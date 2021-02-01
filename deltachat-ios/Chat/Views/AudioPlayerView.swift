import Foundation
import UIKit

open class AudioPlayerView: UIView {

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

    /// The time duration lable to display on audio messages.
    private lazy var durationLabel: UILabel = {
        let durationLabel = UILabel(frame: CGRect.zero)
        durationLabel.textAlignment = .right
        durationLabel.font = UIFont.preferredFont(forTextStyle: .body)
        durationLabel.adjustsFontForContentSizeCategory = true
        durationLabel.text = "0:00"
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.isAccessibilityElement = false
        return durationLabel
    }()

    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = 0.0
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isAccessibilityElement = false
        return progressView
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

        let playButtonConstraints = [playButton.constraintCenterYTo(self),
                                     playButton.constraintAlignLeadingTo(self, paddingLeading: 12)]
        let durationLabelConstraints = [durationLabel.constraintAlignTrailingTo(self, paddingTrailing: 12),
                                        durationLabel.constraintCenterYTo(self)]
        self.addConstraints(playButtonConstraints)
        self.addConstraints(durationLabelConstraints)

        progressView.addConstraints(left: playButton.rightAnchor,
                                    right: durationLabel.leftAnchor,
                                    centerY: self.centerYAnchor,
                                    leftConstant: 8,
                                    rightConstant: 8)
        let height = self.heightAnchor.constraint(equalTo: playButton.heightAnchor)
        height.priority = .required
        height.isActive = true
    }

    open func setupSubviews() {
        self.addSubview(playButton)
        self.addSubview(durationLabel)
        self.addSubview(progressView)
        setupConstraints()
    }

    open func reset() {
        progressView.progress = 0
        playButton.isSelected = false
        durationLabel.text = "0:00"
        playButton.accessibilityLabel = String.localized("menu_play")
    }

    open func setProgress(_ progress: Float) {
        progressView.progress = progress
    }

    open func setDuration(duration: Double) {
        var formattedTime = "0:00"
        // print the time as 0:ss if duration is up to 59 seconds
        // print the time as m:ss if duration is up to 59:59 seconds
        // print the time as h:mm:ss for anything longer
        if duration < 60 {
            formattedTime = String(format: "0:%.02d", Int(duration.rounded(.up)))
        } else if duration < 3600 {
            formattedTime = String(format: "%.02d:%.02d", Int(duration/60), Int(duration) % 60)
        } else {
            let hours = Int(duration/3600)
            let remainingMinutsInSeconds = Int(duration) - hours*3600
            formattedTime = String(format: "%.02d:%.02d:%.02d", hours, Int(remainingMinutsInSeconds/60), Int(remainingMinutsInSeconds) % 60)
        }

        durationLabel.text = formattedTime
    }

    open func showPlayLayout(_ play: Bool) {
        playButton.isSelected = play
        playButton.accessibilityLabel = play ? String.localized("menu_pause") : String.localized("menu_play")
    }
}
