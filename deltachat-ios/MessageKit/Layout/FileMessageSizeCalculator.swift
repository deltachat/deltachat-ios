import Foundation
import UIKit

open class FileMessageSizeCalculator: MessageSizeCalculator {

    var defaultFileMessageCellWidth: CGFloat {
        switch UIApplication.shared.statusBarOrientation {
        case .landscapeLeft, .landscapeRight:
            return UIScreen.main.bounds.size.width * 0.66
        default:
            return UIScreen.main.bounds.size.width * 0.85
        }
    }

    private var incomingMessageLabelInsets = UIEdgeInsets(top: 0,
                                                         left: FileMessageCell.insetHorizontalBig,
                                                         bottom: FileMessageCell.insetVertical,
                                                         right: FileMessageCell.insetHorizontalSmall)
    private var outgoingMessageLabelInsets = UIEdgeInsets(top: 0,
                                                         left: FileMessageCell.insetHorizontalSmall,
                                                         bottom: FileMessageCell.insetVertical,
                                                         right: FileMessageCell.insetHorizontalBig)

    private var messageLabelFont = UIFont.preferredFont(forTextStyle: .body)

    internal func messageLabelInsets(for message: MessageType) -> UIEdgeInsets {
        let dataSource = messagesLayout.messagesDataSource
        let isFromCurrentSender = dataSource.isFromCurrentSender(message: message)
        return isFromCurrentSender ? outgoingMessageLabelInsets : incomingMessageLabelInsets
    }

    open override func messageContainerSize(for message: MessageType) -> CGSize {
        let sizeForMediaItem = { (maxWidth: CGFloat, item: MediaItem) -> CGSize in
            var messageContainerSize = CGSize(width: maxWidth, height: FileView.defaultHeight)
            switch message.kind {
            case .fileText(let mediaItem):
                if let messageText = mediaItem.text?[MediaItemConstants.messageText], !messageText.string.isEmpty {
                    let messageTextHeight = messageText.height(withConstrainedWidth: maxWidth - self.messageLabelInsets(for: message).horizontal)
                    messageContainerSize.height += messageTextHeight + self.messageLabelInsets(for: message).bottom
                }
            default:
                safe_fatalError("only fileText types can be calculated by FileMessageSizeCalculator")
            }
            return messageContainerSize
        }

        switch message.kind {
        case .fileText(let item):
            let maxImageWidth = item.image != nil ? messageContainerMaxWidth(for: message) : defaultFileMessageCellWidth
            return sizeForMediaItem(maxImageWidth, item)
        default:
            safe_fatalError("messageContainerSize received unhandled MessageDataType: \(message.kind)")
            return .zero
        }
    }

    open override func configure(attributes: UICollectionViewLayoutAttributes) {
        super.configure(attributes: attributes)
        guard let attributes = attributes as? MessagesCollectionViewLayoutAttributes else { return }

        let dataSource = messagesLayout.messagesDataSource
        let indexPath = attributes.indexPath
        let message = dataSource.messageForItem(at: indexPath, in: messagesLayout.messagesCollectionView)

        switch message.kind {
        case .fileText:
            attributes.messageLabelInsets = messageLabelInsets(for: message)
            attributes.messageLabelFont = messageLabelFont
        default:
            break
        }
    }
}
