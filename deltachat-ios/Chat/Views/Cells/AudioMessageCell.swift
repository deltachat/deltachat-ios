import UIKit
import DcCore

// NewAudioMessageCellDelegate is for sending events to NewAudioController.
// do not confuse with BaseMessageCellDelegate that is for sending events to ChatViewControllerNew.
public protocol AudioMessageCellDelegate: AnyObject {
    func playButtonTapped(cell: AudioMessageCell, messageId: Int)
}

public class AudioMessageCell: BaseMessageCell {

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

    override func update(msg: DcMsg, messageStyle: UIRectCorner, isAvatarVisible: Bool, isGroup: Bool) {
        //audioPlayerView.reset()
        messageId = msg.id
        if let text = msg.text {
            mainContentView.spacing = text.isEmpty ? 0 : 8
            messageLabel.text = text
        } else {
            mainContentView.spacing = 0
        }

        super.update(msg: msg, messageStyle: messageStyle, isAvatarVisible: isAvatarVisible, isGroup: isGroup)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        mainContentView.spacing = 0
        messageId = 0
        delegate = nil
        audioPlayerView.reset()
    }
}
