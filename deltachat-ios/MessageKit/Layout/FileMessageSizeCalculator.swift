import Foundation
import UIKit

open class FileMessageSizeCalculator: MessageSizeCalculator {

    let defaultFileMessageCellWidth = 250
    let defaultFileMessageCellHeight = 100

    public var incomingMessageLabelInsets = UIEdgeInsets(top: FileMessageCell.insetTop,
                                                         left: FileMessageCell.insetHorizontalBig,
                                                         bottom: FileMessageCell.insetBottom,
                                                         right: FileMessageCell.insetHorizontalSmall)
    public var outgoingMessageLabelInsets = UIEdgeInsets(top: FileMessageCell.insetTop,
                                                         left: FileMessageCell.insetHorizontalSmall,
                                                         bottom: FileMessageCell.insetBottom,
                                                         right: FileMessageCell.insetHorizontalBig)

    public var messageLabelFont = UIFont.preferredFont(forTextStyle: .body)

    internal func messageLabelInsets(for message: MessageType) -> UIEdgeInsets {
        let dataSource = messagesLayout.messagesDataSource
        let isFromCurrentSender = dataSource.isFromCurrentSender(message: message)
        return isFromCurrentSender ? outgoingMessageLabelInsets : incomingMessageLabelInsets
    }

    open override func messageContainerSize(for message: MessageType) -> CGSize {


        let sizeForMediaItem = { (maxWidth: CGFloat, item: MediaItem) -> CGSize in
            var maxMediaTextWidth: CGFloat = 0  // width of the attached text message
            var maxMediaTitleWidth: CGFloat = 0 // width of the file name text & file size text
            var mediaTitleHeight: CGFloat = 0
            var mediaSubtitleHeight: CGFloat = 0
            var messageTextHeight: CGFloat = 0
            var itemWidth: CGFloat = 0

            maxMediaTextWidth = maxWidth - self.messageLabelInsets(for: message).horizontal
            if item.image == nil {
                itemWidth = maxWidth
                maxMediaTitleWidth = maxMediaTextWidth
            } else {
                itemWidth = item.size.width
                // the media title/subtitle and subtitle is right to the badge view
                // the max width of the title/subtitle depends on the available cell
                // width minus fixed paddings and the badge size
                maxMediaTitleWidth = maxWidth - FileView.badgeSize - (3 * FileMessageCell.insetHorizontalSmall)
            }

            var imageHeight = item.size.height
            if maxWidth < item.size.width {
                // Maintain the ratio if width is too great
                imageHeight = maxWidth * item.size.height / item.size.width
                itemWidth = maxWidth
            }

            var messageContainerSize = CGSize(width: itemWidth, height: imageHeight)
            switch message.kind {
            case .fileText(let mediaItem):
                if let mediaTitle = mediaItem.text?[MediaItemConstants.mediaTitle] {
                    mediaTitleHeight = mediaTitle.height(withConstrainedWidth: maxMediaTitleWidth)
                    messageContainerSize.height += mediaTitleHeight
                }
                if let mediaSubtitle = mediaItem.text?[MediaItemConstants.mediaSubtitle] {
                    mediaSubtitleHeight = mediaSubtitle.height(withConstrainedWidth: maxMediaTitleWidth)
                    messageContainerSize.height += mediaSubtitleHeight
                }

                if let messageText = mediaItem.text?[MediaItemConstants.messageText], !messageText.string.isEmpty {
                    messageTextHeight = messageText.height(withConstrainedWidth: maxMediaTextWidth)
                    messageContainerSize.height += messageTextHeight
                    messageContainerSize.height +=  self.messageLabelInsets(for: message).vertical
                }

            default:
                fatalError("only fileText types can be calculated by FileMessageSizeCalculator")
            }

            return messageContainerSize
        }

        switch message.kind {
        case .fileText(let item):

            let maxImageWidth = item.image != nil ? messageContainerMaxWidth(for: message) : 280
            return sizeForMediaItem(maxImageWidth, item)
        default:
            fatalError("messageContainerSize received unhandled MessageDataType: \(message.kind)")
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
