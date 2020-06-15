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

import UIKit

/// A subclass of `MessageContentCell` used to display video and audio messages.
open class MediaMessageCell: MessageContentCell {

    /// The play button view to display on video messages.
    open lazy var playButtonView: PlayButtonView = {
        let playButtonView = PlayButtonView()
        return playButtonView
    }()

    /// The image view display the media content.
    open var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    private lazy var imageViewHeightConstraint: NSLayoutConstraint = {
        return imageView.heightAnchor.constraint(equalToConstant: 350)
    }()

    // MARK: - Methods

    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        imageView.fillSuperview()
        playButtonView.centerInSuperview()
        playButtonView.constraint(equalTo: CGSize(width: 50, height: 50))
    }

    open override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(imageView)
        messageContainerView.addSubview(playButtonView)
        setupConstraints()
    }
    
    open override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
    }

    open override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)

        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            fatalError(MessageKitError.nilMessagesDisplayDelegate)
        }

        switch message.kind {
        case .photo(let mediaItem):
            imageViewHeightConstraint.isActive = false
            imageView.image = mediaItem.image ?? mediaItem.placeholderImage
            playButtonView.isHidden = true
        case .video(let mediaItem):
            if let url = mediaItem.url {
                imageViewHeightConstraint.isActive = true
                if let image = mediaItem.image {
                    imageView.image = image
                } else {
                    // no image in cache
                    imageView.loadVideoThumbnail(from: url, placeholderImage: mediaItem.placeholderImage, completionHandler: { [weak self] thumbnail in
                        if let image = thumbnail {
                            self?.cache(thumbnail: image, key: url.absoluteString)
                        }
                    })
                }
            } else {
                imageView.image = mediaItem.placeholderImage
            }
            playButtonView.isHidden = false
        default:
            break
        }

        displayDelegate.configureMediaMessageImageView(imageView, for: message, at: indexPath, in: messagesCollectionView)
    }

    private func cache(thumbnail image: UIImage, key: String) {
        ThumbnailCache.shared.storeImage(image: image, key: key)
    }
}
