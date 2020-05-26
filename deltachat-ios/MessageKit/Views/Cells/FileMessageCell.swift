import UIKit

// A subclass of `MessageContentCell` used to display mixed media messages.
open class FileMessageCell: MessageContentCell {

    static let insetBottom: CGFloat = 12
    static let insetHorizontalBig: CGFloat = 23
    static let insetHorizontalSmall: CGFloat = 12

    // MARK: - Properties
    var fileViewLeadingPadding: CGFloat = 0 {
        didSet {
            fileViewLeadingAlignment.constant = fileViewLeadingPadding
        }
    }

    private lazy var fileViewLeadingAlignment: NSLayoutConstraint = {
        return fileView.constraintAlignLeadingTo(messageContainerView, paddingLeading: 0)
    }()

    /// The `MessageCellDelegate` for the cell.
    open override weak var delegate: MessageCellDelegate? {
        didSet {
            messageLabel.delegate = delegate
        }
    }

    /// The label used to display the message's text.
    open var messageLabel = MessageLabel()

    private lazy var fileView: FileView = {
        let marginInsets = NSDirectionalEdgeInsets(top: FileMessageCell.insetHorizontalSmall,
                                                   leading: FileMessageCell.insetHorizontalSmall,
                                                   bottom: FileMessageCell.insetHorizontalSmall,
                                                   trailing: FileMessageCell.insetHorizontalSmall)
        let fileView = FileView(directionalLayoutMargins: marginInsets)
        fileView.translatesAutoresizingMaskIntoConstraints = false
        return fileView
    }()

    // MARK: - Methods

    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints(for messageKind: MessageKind) {
        messageContainerView.removeConstraints(messageContainerView.constraints)

        let fileViewConstraints = [fileView.constraintHeightTo(FileView.defaultHeight),
                                    fileViewLeadingAlignment,
                                    fileView.constraintAlignTrailingTo(messageContainerView),
                                    fileView.constraintAlignTopTo(messageContainerView),
                                    ]
        messageContainerView.addConstraints(fileViewConstraints)

        messageLabel.frame = CGRect(x: 0,
                                    y: FileView.defaultHeight,
                                    width: messageContainerView.frame.width,
                                    height: getMessageLabelHeight())
    }

    private func getMessageLabelHeight() -> CGFloat {
        if let text = messageLabel.attributedText, !text.string.isEmpty {
            let height = (text.height(withConstrainedWidth:
                messageContainerView.frame.width -
                    FileMessageCell.insetHorizontalSmall -
                    FileMessageCell.insetHorizontalBig))
            return height + FileMessageCell.insetBottom
        }
        return 0
    }

    open override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(fileView)
        messageContainerView.addSubview(messageLabel)
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        self.messageLabel.attributedText = nil
        self.fileView.prepareForReuse()
    }

    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        if let attributes = layoutAttributes as? MessagesCollectionViewLayoutAttributes {
            messageLabel.textInsets = attributes.messageLabelInsets
            messageLabel.messageLabelFont = attributes.messageLabelFont
            fileViewLeadingPadding = attributes.messageLabelInsets.left
        }
    }

    // MARK: - Configure Cell
    open override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)

        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            fatalError(MessageKitError.nilMessagesDisplayDelegate)
        }

        switch message.kind {
        case .fileText(let mediaItem):
            configureFileView(for: mediaItem)
            configureMessageLabel(for: mediaItem,
                                             with: displayDelegate,
                                             message: message,
                                             at: indexPath,
                                             in: messagesCollectionView)
        default:
            fatalError("Unexpected message kind in FileMessageCell")
        }
        setupConstraints(for: message.kind)
    }

    private func configureFileView(for mediaItem: MediaItem) {
        fileView.configureFor(mediaItem: mediaItem)
    }

    private func configureMessageLabel(for mediaItem: MediaItem,
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
            messageLabel.attributedText = mediaItem.text?[MediaItemConstants.messageText]
        }
    }

    /// Used to handle the cell's contentView's tap gesture.
    /// Return false when the contentView does not need to handle the gesture.
    open override func cellContentView(canHandle touchPoint: CGPoint) -> Bool {
        let touchPointWithoutImageHeight = CGPoint(x: touchPoint.x,
                                                   y: touchPoint.y - fileView.frame.height)
        return messageLabel.handleGesture(touchPointWithoutImageHeight)
    }
}
