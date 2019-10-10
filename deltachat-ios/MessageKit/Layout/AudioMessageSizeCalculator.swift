/*
 MIT License

 Copyright (c) 2017-2019 MessageKit

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import Foundation
import UIKit

open class AudioMessageSizeCalculator: MessageSizeCalculator {

    public var incomingMessageLabelInsets = UIEdgeInsets(top: AudioMessageCell.insetTop,
                                                         left: AudioMessageCell.insetHorizontalBig,
                                                         bottom: AudioMessageCell.insetBottom,
                                                         right: AudioMessageCell.insetHorizontalSmall)
   public var outgoingMessageLabelInsets = UIEdgeInsets(top: AudioMessageCell.insetTop,
                                                        left: AudioMessageCell.insetHorizontalSmall,
                                                        bottom: AudioMessageCell.insetBottom,
                                                        right: AudioMessageCell.insetHorizontalBig)

    public var messageLabelFont = UIFont.preferredFont(forTextStyle: .body)


    internal func messageLabelInsets(for message: MessageType) -> UIEdgeInsets {
        let dataSource = messagesLayout.messagesDataSource
        let isFromCurrentSender = dataSource.isFromCurrentSender(message: message)
        return isFromCurrentSender ? outgoingMessageLabelInsets : incomingMessageLabelInsets
    }

    open override func messageContainerSize(for message: MessageType) -> CGSize {
        switch message.kind {
        case .audio(let item):
            let maxWidth = messageContainerMaxWidth(for: message)
            var itemWidth = item.size.width
            var itemHeight = item.size.height

            if maxWidth < itemWidth {
                // Maintain the ratio if width is too great
                itemHeight = maxWidth * item.size.height / item.size.width
                itemWidth = maxWidth
            }

            let maxTextWidth = itemWidth - self.messageLabelInsets(for: message).horizontal
            var messageContainerSize = CGSize(width: itemWidth, height: itemHeight)
            if let text = item.text {
                let textHeight = text.height(withConstrainedWidth: maxTextWidth)
                messageContainerSize.height += textHeight
                messageContainerSize.height +=  self.messageLabelInsets(for: message).vertical
            }
            return messageContainerSize
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
        case .audio:
            attributes.messageLabelInsets = messageLabelInsets(for: message)
            attributes.messageLabelFont = messageLabelFont
        default:
            break
        }
    }
}
