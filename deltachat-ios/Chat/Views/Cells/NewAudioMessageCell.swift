import UIKit
import DcCore

// NewAudioMessageCellDelegate is for sending events to NewAudioController.
// do not confuse with BaseMessageCellDelegate that is for sending events to ChatViewControllerNew.
public protocol NewAudioMessageCellDelegate: AnyObject {
    func playButtonTapped(cell: NewAudioMessageCell, messageId: Int)
}

public class NewAudioMessageCell: BaseMessageCell {

    public weak var delegate: NewAudioMessageCellDelegate?

    lazy var audioPlayerView: NewAudioPlayerView = {
        let view = NewAudioPlayerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = UIFont.preferredFont(for: .body, weight: .regular)
        return label
    }()

    private var messageId: Int = 0

    override func setupSubviews() {
        super.setupSubviews()
        let spacerView = UIView()
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        mainContentView.addArrangedSubview(audioPlayerView)
        mainContentView.addArrangedSubview(messageLabel)
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
        messageLabel.text = nil
        messageLabel.attributedText = nil
        messageId = 0
        delegate = nil
        audioPlayerView.reset()
    }
}
