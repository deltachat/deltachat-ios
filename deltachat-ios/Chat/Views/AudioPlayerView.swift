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

    /// The playback speed badge button (now hidden, speed shown in status view)
    lazy var speedButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true  // Always hidden, speed shown in status view
        return button
    }()
    
    /// Callback for when speed button is tapped
    public var onSpeedButtonTapped: (() -> Void)?
    
    /// Callback for when user seeks to a new position (value between 0.0 and 1.0)
    public var onSeek: ((Float) -> Void)?

    private lazy var waveformView: WaveformView = {
        let waveformView = WaveformView()
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformView.isAccessibilityElement = false
        return waveformView
    }()
    
    /// The scrubber line that shows current playback position and can be dragged
    private lazy var scrubberLine: UIView = {
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = .white
        line.layer.cornerRadius = 1
        line.layer.shadowColor = UIColor.black.cgColor
        line.layer.shadowOffset = CGSize(width: 0, height: 0)
        line.layer.shadowRadius = 2
        line.layer.shadowOpacity = 0.3
        line.isUserInteractionEnabled = false
        return line
    }()
    
    /// Container view for scrubber to handle touch events
    private lazy var scrubberContainer: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        return container
    }()
    
    private var scrubberLeadingConstraint: NSLayoutConstraint?
    private var isDragging = false
    private var currentProgress: Float = 0.0

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
        let speedButtonConstraints = [speedButton.constraintAlignTrailingTo(self, paddingTrailing: 12),
                                      speedButton.constraintCenterYTo(self)]
        self.addConstraints(playButtonConstraints)
        self.addConstraints(speedButtonConstraints)

        waveformView.addConstraints(left: playButton.rightAnchor,
                                    right: self.rightAnchor,
                                    centerY: self.centerYAnchor,
                                    leftConstant: 8,
                                    rightConstant: 12)
        // Set a minimum height for the waveform
        waveformView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        let height = self.heightAnchor.constraint(equalTo: playButton.heightAnchor)
        height.priority = .required
        height.isActive = true
        
        // Scrubber container constraints - covers the waveform area
        NSLayoutConstraint.activate([
            scrubberContainer.leftAnchor.constraint(equalTo: waveformView.leftAnchor),
            scrubberContainer.rightAnchor.constraint(equalTo: waveformView.rightAnchor),
            scrubberContainer.topAnchor.constraint(equalTo: waveformView.topAnchor),
            scrubberContainer.bottomAnchor.constraint(equalTo: waveformView.bottomAnchor)
        ])
        
        // Scrubber line constraints - height matches play button
        scrubberLine.widthAnchor.constraint(equalToConstant: 2).isActive = true
        scrubberLine.heightAnchor.constraint(equalTo: playButton.heightAnchor).isActive = true
        scrubberLine.centerYAnchor.constraint(equalTo: scrubberContainer.centerYAnchor).isActive = true
        
        // Position scrubber at the start initially
        scrubberLeadingConstraint = scrubberLine.leadingAnchor.constraint(equalTo: scrubberContainer.leadingAnchor)
        scrubberLeadingConstraint?.isActive = true
    }

    open func setupSubviews() {
        self.addSubview(playButton)
        self.addSubview(speedButton)
        self.addSubview(waveformView)
        self.addSubview(scrubberContainer)
        scrubberContainer.addSubview(scrubberLine)
        
        speedButton.addTarget(self, action: #selector(speedButtonTapped), for: .touchUpInside)
        
        // Add pan gesture for scrubbing
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scrubberContainer.addGestureRecognizer(panGesture)
        
        // Add tap gesture for quick seek
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scrubberContainer.addGestureRecognizer(tapGesture)
        
        setupConstraints()
    }
    
    @objc private func speedButtonTapped() {
        onSpeedButtonTapped?()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: scrubberContainer)
        let progress = Float(max(0, min(location.x, scrubberContainer.bounds.width)) / scrubberContainer.bounds.width)
        
        switch gesture.state {
        case .began:
            isDragging = true
        case .changed:
            updateScrubberPosition(progress: progress)
            waveformView.setProgress(progress)
        case .ended, .cancelled:
            isDragging = false
            onSeek?(progress)
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: scrubberContainer)
        let progress = Float(max(0, min(location.x, scrubberContainer.bounds.width)) / scrubberContainer.bounds.width)
        
        updateScrubberPosition(progress: progress)
        waveformView.setProgress(progress)
        onSeek?(progress)
    }
    
    private func updateScrubberPosition(progress: Float) {
        currentProgress = progress
        let offset = CGFloat(progress) * scrubberContainer.bounds.width
        scrubberLeadingConstraint?.constant = offset
    }

    open func reset() {
        waveformView.reset()
        playButton.isSelected = false
        playButton.accessibilityLabel = String.localized("menu_play")
        currentProgress = 0.0
        updateScrubberPosition(progress: 0.0)
    }

    open func setProgress(_ progress: Float) {
        waveformView.setProgress(progress)
        // Only update scrubber if not currently dragging
        if !isDragging {
            updateScrubberPosition(progress: progress)
        }
    }

    open func formatDuration(_ duration: Double) -> String {
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
        return formattedTime
    }

    open func showPlayLayout(_ play: Bool) {
        playButton.isSelected = play
        playButton.accessibilityLabel = play ? String.localized("menu_pause") : String.localized("menu_play")
        // Speed button stays hidden, speed is shown in status view
    }
    
    open func formatPlaybackSpeed(_ speed: Float) -> String {
        if speed == 1.0 {
            return "1x"
        } else if speed == 1.5 {
            return "1.5x"
        } else if speed == 2.0 {
            return "2x"
        } else {
            return String(format: "%.1fx", speed)
        }
    }
    
    /// Configure waveform and scrubber colors based on message context
    /// - Parameters:
    ///   - isFromCurrentSender: Whether the message is from the current sender
    ///   - bubbleColor: Optional custom bubble color to derive waveform colors from
    open func configureWaveformColors(isFromCurrentSender: Bool, bubbleColor: UIColor? = nil) {
        // Update scrubber color for contrast
        if let bubbleColor = bubbleColor {
            let isLightBubble = bubbleColor.isLight()
            scrubberLine.backgroundColor = isLightBubble ? .darkGray : .white
        } else {
            scrubberLine.backgroundColor = isFromCurrentSender ? .white : .darkGray
        }
        
        if let bubbleColor = bubbleColor {
            // Check if bubble is light or dark to ensure good contrast
            let isLightBubble = bubbleColor.isLight()
            
            if isLightBubble {
                // For light bubbles, use darker colors for visibility
                waveformView.playedColor = bubbleColor.darker(by: 0.5) ?? .darkGray
                waveformView.unplayedColor = bubbleColor.darker(by: 0.25) ?? .lightGray
            } else {
                // For dark bubbles, use lighter colors for visibility
                waveformView.playedColor = bubbleColor.lighter(by: 0.4) ?? .white
                waveformView.unplayedColor = bubbleColor.lighter(by: 0.2) ?? .lightGray
            }
        } else {
            // Use default colors based on message direction
            if isFromCurrentSender {
                // Sent messages - use darker green for played, lighter for unplayed
                waveformView.playedColor = UIColor.themeColor(
                    light: UIColor.rgb(red: 96, green: 160, blue: 82),
                    dark: UIColor.rgb(red: 76, green: 140, blue: 62)
                )
                waveformView.unplayedColor = UIColor.themeColor(
                    light: UIColor.rgb(red: 180, green: 220, blue: 170),
                    dark: UIColor.rgb(red: 56, green: 100, blue: 42)
                )
            } else {
                // Received messages - use blue/gray tones
                waveformView.playedColor = .systemBlue
                waveformView.unplayedColor = .systemGray3
            }
        }
    }
}
