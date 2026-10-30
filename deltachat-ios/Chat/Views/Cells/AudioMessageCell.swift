import UIKit
import DcCore

// NewAudioMessageCellDelegate is for sending events to NewAudioController.
// do not confuse with BaseMessageCellDelegate that is for sending events to ChatViewControllerNew.
public protocol AudioMessageCellDelegate: AnyObject {
    func playButtonTapped(cell: AudioMessageCell, messageId: Int)
    func getAudioDuration(messageId: Int, successHandler: @escaping (Int, Double) -> Void)

}

public class AudioMessageCell: BaseMessageCell, ReusableCell {

    static let reuseIdentifier = "AudioMessageCell"

    public weak var delegate: AudioMessageCellDelegate?

    lazy var audioPlayerView: AudioPlayerView = {
        let view = AudioPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var transcriptionLabel: PaddingTextView = {
        let view = PaddingTextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = UIFont.preferredFont(forTextStyle: .footnote)
        view.textColor = .secondaryLabel
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 8
        view.label.adjustsFontForContentSizeCategory = true
        view.isHidden = true
        view.isAccessibilityElement = false
        return view
    }()

    private var transcriptionTopConstraint: NSLayoutConstraint?
    private var transcriptionHiddenHeightConstraint: NSLayoutConstraint?

    private var messageId: Int = 0

    override func setupSubviews() {
        super.setupSubviews()
        mainContentView.addArrangedSubview(audioPlayerView)
        mainContentView.addArrangedSubview(messageLabel)
        bottomConstraint?.isActive = false
        contentView.addSubview(transcriptionLabel)
        transcriptionTopConstraint = transcriptionLabel.topAnchor.constraint(equalTo: messageBackgroundContainer.bottomAnchor)
        transcriptionTopConstraint?.isActive = true
        transcriptionHiddenHeightConstraint = transcriptionLabel.heightAnchor.constraint(equalToConstant: 0)
        transcriptionHiddenHeightConstraint?.isActive = true
        NSLayoutConstraint.activate([
            transcriptionLabel.leadingAnchor.constraint(equalTo: messageBackgroundContainer.leadingAnchor),
            transcriptionLabel.trailingAnchor.constraint(equalTo: messageBackgroundContainer.trailingAnchor),
            transcriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3)
        ])
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
        audioPlayerView.widthAnchor.constraint(equalToConstant: 250).isActive = true
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onPlayButtonTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        audioPlayerView.playButton.addGestureRecognizer(gestureRecognizer)
    }

    @objc public func onPlayButtonTapped() {
        delegate?.playButtonTapped(cell: self, messageId: messageId)
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, showViewCount: Bool, searchText: String? = nil, highlight: Bool) {
        messageId = msg.id
        if let text = msg.text {
            messageLabel.text = text
        }
        messageLabel.isHidden = !msg.hasText
        mainContentView.spacing = msg.hasText ? 8 : 0
        if msg.type == DC_MSG_VOICE {
            a11yDcType = String.localized("voice_message")
        } else {
            a11yDcType = String.localized("audio")
        }
        
        delegate?.getAudioDuration(messageId: messageId, successHandler: { [weak self] messageId, duration in
            if let self,
               messageId == self.messageId {
                self.audioPlayerView.setDuration(duration: duration)
            }
        })
        

        super.update(dcContext: dcContext,
                     msg: msg,
                     messageStyle: messageStyle,
                     showAvatar: showAvatar,
                     showName: showName,
                     showViewCount: showViewCount,
                     searchText: searchText,
                     highlight: highlight)
    }

    func updateTranscription(_ text: String?, isTranscribing: Bool) {
        transcriptionLabel.text = isTranscribing ? String.localized("transcribing_voice_message") : text
        let isVisible = transcriptionLabel.text != nil
        transcriptionLabel.isHidden = !isVisible
        transcriptionLabel.paddingTop = isVisible ? 8 : 0
        transcriptionLabel.paddingBottom = isVisible ? 8 : 0
        transcriptionLabel.paddingLeading = isVisible ? 10 : 0
        transcriptionLabel.paddingTrailing = isVisible ? 10 : 0
        transcriptionHiddenHeightConstraint?.isActive = !isVisible
        let reactionSpace: CGFloat = reactionsView.isHidden ? 0 : 20
        transcriptionTopConstraint?.constant = reactionSpace + (isVisible ? 6 : 0)
    }

    public override func accessibilityElementDidBecomeFocused() {
        super.accessibilityElementDidBecomeFocused()
        if let text = transcriptionLabel.text {
            accessibilityLabel = (accessibilityLabel ?? "") + ", \(text)"
        }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        mainContentView.spacing = 0
        messageId = 0
        delegate = nil
        audioPlayerView.reset()
        updateTranscription(nil, isTranscribing: false)
    }
}
