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

    private var messageId: Int = 0

    override func setupSubviews() {
        super.setupSubviews()
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addArrangedSubview(audioPlayerView)
        mainContentView.addArrangedSubview(messageLabel)
        messageLabel.paddingLeading = 12
        messageLabel.paddingTrailing = 12
        audioPlayerView.constraintWidthTo(250).isActive = true
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onPlayButtonTapped))
        gestureRecognizer.numberOfTapsRequired = 1
        audioPlayerView.playButton.addGestureRecognizer(gestureRecognizer)
    }

    @objc public func onPlayButtonTapped() {
        delegate?.playButtonTapped(cell: self, messageId: messageId)
    }

    override func update(dcContext: DcContext, msg: DcMsg, messageStyle: UIRectCorner, showAvatar: Bool, showName: Bool, searchText: String? = nil, highlight: Bool) {
        messageId = msg.id
        if let text = msg.text {
            mainContentView.spacing = text.isEmpty ? 0 : 8
            messageLabel.text = text
        } else {
            mainContentView.spacing = 0
        }
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
                     searchText: searchText,
                     highlight: highlight)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        mainContentView.spacing = 0
        messageId = 0
        delegate = nil
        audioPlayerView.reset()
    }
}
