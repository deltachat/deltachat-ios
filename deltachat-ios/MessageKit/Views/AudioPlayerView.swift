import Foundation
import UIKit

open class AudioPlayerView: UIView {
    //open weak var playerDelegate: AudioPlayerDelegate?

    /// The play button view to display on audio messages.
    private lazy var playButton: UIButton = {
        let playButton = UIButton(type: .custom)
        let playImage = UIImage(named: "play")
        let pauseImage = UIImage(named: "pause")
        playButton.setImage(playImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        playButton.setImage(pauseImage?.withRenderingMode(.alwaysTemplate), for: .selected)
        playButton.translatesAutoresizingMaskIntoConstraints = false
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
        return durationLabel
    }()

    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = 0.0
        progressView.translatesAutoresizingMaskIntoConstraints = false
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
        playButton.constraint(equalTo: CGSize(width: 35, height: 35))

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
    }

    open func didTapPlayButton(_ gesture: UIGestureRecognizer) -> Bool {
        let touchLocation = gesture.location(in: self)
        // compute play button touch area, currently play button size is (25, 25) which is hardly touchable
        // add 10 px around current button frame and test the touch against this new frame
        let playButtonTouchArea = CGRect(playButton.frame.origin.x - 10.0,
                                         playButton.frame.origin.y - 10,
                                         playButton.frame.size.width + 20,
                                         playButton.frame.size.height + 20)
        let translateTouchLocation = convert(touchLocation, to: self)
        if playButtonTouchArea.contains(translateTouchLocation) {
            return true
        } else {
            return false
        }
    }

    open func setTintColor(_ color: UIColor) {
        playButton.imageView?.tintColor = tintColor
        durationLabel.textColor = tintColor
        progressView.tintColor = tintColor
    }

    open func setProgress(_ progress: Float) {
        progressView.progress = progress
    }

    open func setDuration(formattedText: String) {
        durationLabel.text = formattedText
    }

    open func showPlayLayout(_ play: Bool) {
        playButton.isSelected = play
    }
}
