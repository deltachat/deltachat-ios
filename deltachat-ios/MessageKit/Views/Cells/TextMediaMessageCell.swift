import UIKit

// A subclass of `MessageContentCell` used to display mixed media messages.
open class TextMediaMessageCell: MessageContentCell {

    public static let insetTop: CGFloat = 12
    public static let insetBottom: CGFloat = 12
    public static let insetHorizontalBig: CGFloat = 23
    public static let insetHorizontalSmall: CGFloat = 12


    // MARK: - Properties
    /// The `MessageCellDelegate` for the cell.
    open override weak var delegate: MessageCellDelegate? {
        didSet {
            messageLabel.delegate = delegate
        }
    }

    /// The label used to display the message's text.
    open var messageLabel = MessageLabel()

    /// The image view display the media content.
    open var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// The play button view to display on video messages.
    open lazy var playButtonView: PlayButtonView = {
        let playButtonView = PlayButtonView()
        return playButtonView
    }()

    // MARK: - Methods

    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        if let attributes = layoutAttributes as? MessagesCollectionViewLayoutAttributes {
            messageLabel.textInsets = attributes.messageLabelInsets
            messageLabel.messageLabelFont = attributes.messageLabelFont
        }
    }

    func getMessageLabelHeight() -> CGFloat {
        if let text = messageLabel.attributedText {
            let height = (text.height(withConstrainedWidth:
                messageContainerView.frame.width -
                    TextMediaMessageCell.insetHorizontalSmall -
                    TextMediaMessageCell.insetHorizontalBig))
            return height + TextMediaMessageCell.insetBottom + TextMediaMessageCell.insetTop
        }
        return 0
    }

    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        messageContainerView.removeConstraints(messageContainerView.constraints)
        let imageViewHeight = messageContainerView.frame.height - getMessageLabelHeight()

        let imageViewConstraints = [imageView.constraintCenterXTo(messageContainerView),
                                    imageView.constraintAlignLeadingTo(messageContainerView),
                                    imageView.constraintAlignTrailingTo(messageContainerView),
                                    imageView.constraintAlignTopTo(messageContainerView),
                                    imageView.heightAnchor.constraint(equalToConstant: imageViewHeight)
                                    ]

        messageContainerView.addConstraints(imageViewConstraints)

        playButtonView.constraint(equalTo: CGSize(width: 35, height: 35))
        let playButtonViewConstraints = [ playButtonView.constraintCenterXTo(imageView),
                                          playButtonView.constraintCenterYTo(imageView)]
        messageContainerView.addConstraints(playButtonViewConstraints)

        messageLabel.frame = CGRect(x: 0,
                                    y: messageContainerView.frame.height - getMessageLabelHeight(),
                                    width: messageContainerView.frame.width,
                                    height: getMessageLabelHeight())
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        self.messageLabel.attributedText = nil
        self.messageLabel.text = nil
    }

    open override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(imageView)
        messageContainerView.addSubview(playButtonView)
        messageContainerView.addSubview(messageLabel)
    }

    open override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)

        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            fatalError(MessageKitError.nilMessagesDisplayDelegate)
        }

        switch message.kind {
        case .photoText(let mediaItem):
            configureImageView(for: mediaItem)
            configureMessageLabel(for: mediaItem,
                                  with: displayDelegate,
                                  message: message,
                                  at: indexPath,
                                  in: messagesCollectionView)
            playButtonView.isHidden = true
        case .videoText(let mediaItem):
            configureImageView(for: mediaItem)
            configureMessageLabel(for: mediaItem,
                                  with: displayDelegate,
                                  message: message,
                                  at: indexPath,
                                  in: messagesCollectionView)
            playButtonView.isHidden = false
        default:
            fatalError("Unexpected message kind in TextMediaMessageCell")
        }
        setupConstraints()

        displayDelegate.configureMediaMessageImageView(imageView, for: message, at: indexPath, in: messagesCollectionView)
    }


    func configureImageView(for mediaItem: MediaItem) {
        imageView.image = mediaItem.image ?? mediaItem.placeholderImage
    }
    func configureMessageLabel(for mediaItem: MediaItem,
                               with displayDelegate: MessagesDisplayDelegate,
                               message: MessageType,
                               at indexPath: IndexPath,
                               in messagesCollectionView: MessagesCollectionView) {
        let enabledDetectors = displayDelegate.enabledDetectors(for: message, at: indexPath, in: messagesCollectionView)
        messageLabel.configure {
           messageLabel.enabledDetectors = enabledDetectors
           for detector in enabledDetectors {
               let attributes = displayDelegate.detectorAttributes(for: detector, and: message, at: indexPath)
               messageLabel.setAttributes(attributes, detector: detector)
           }
            messageLabel.attributedText = mediaItem.text
        }
    }

      /// Used to handle the cell's contentView's tap gesture.
      /// Return false when the contentView does not need to handle the gesture.
      open override func cellContentView(canHandle touchPoint: CGPoint) -> Bool {
          return messageLabel.handleGesture(touchPoint)
      }

}
