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

open class MediaMessageSizeCalculator: MessageSizeCalculator {

    private var maxMediaItemHeight: CGFloat {
        return UIScreen.main.bounds.size.height * 0.8
    }

    open override func messageContainerSize(for message: MessageType) -> CGSize {
        let maxWidth = messageContainerMaxWidth(for: message)
        let sizeForMediaItem = { (maxWidth: CGFloat, item: MediaItem) -> CGSize in
            var imageWidth = item.size.width
            var imageHeight = item.size.height
            if maxWidth < item.size.width {
                // Maintain the ratio if width is too great
                imageHeight = maxWidth * item.size.height / item.size.width
                imageWidth = maxWidth
            }

            if self.maxMediaItemHeight < imageHeight {
                // Maintain the ratio if height is too great
                imageWidth = self.maxMediaItemHeight * imageWidth / imageHeight
                imageHeight = self.maxMediaItemHeight
            }

            return CGSize(width: imageWidth, height: imageHeight)
        }
        switch message.kind {
        case .photo(let item):
            return sizeForMediaItem(maxWidth, item)
        case .video(let item):
            return sizeForMediaItem(maxWidth, item)
        default:
            fatalError("messageContainerSize received unhandled MessageDataType: \(message.kind)")
        }
    }
}
