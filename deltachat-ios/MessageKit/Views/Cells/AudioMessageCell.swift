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
import AVFoundation

/// A subclass of `MessageContentCell` used to display video and audio messages.
open class AudioMessageCell: MessageContentCell {

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

    public lazy var audioPlayerView: AudioPlayerView = {
        let audioPlayerView = AudioPlayerView()
        audioPlayerView.translatesAutoresizingMaskIntoConstraints = false
        return audioPlayerView
    }()

    // MARK: - Methods
    /// Responsible for setting up the constraints of the cell's subviews.
    open func setupConstraints() {
        messageContainerView.removeConstraints(messageContainerView.constraints)
        let audioPlayerHeight = messageContainerView.frame.height - getMessageLabelHeight()
        let audioPlayerConstraints = [ audioPlayerView.constraintHeightTo(audioPlayerHeight),
                                       audioPlayerView.constraintAlignLeadingTo(messageContainerView),
                                       audioPlayerView.constraintAlignTrailingTo(messageContainerView),
                                       audioPlayerView.constraintAlignTopTo(messageContainerView)
        ]
        messageContainerView.addConstraints(audioPlayerConstraints)

        messageLabel.frame = CGRect(x: 0,
                                    y: messageContainerView.frame.height - getMessageLabelHeight(),
                                    width: messageContainerView.frame.width,
                                    height: getMessageLabelHeight())
    }

    func getMessageLabelHeight() -> CGFloat {
        if let text = messageLabel.attributedText {
            let height = (text.height(withConstrainedWidth:
                messageContainerView.frame.width -
                    AudioMessageCell.insetHorizontalSmall -
                    AudioMessageCell.insetHorizontalBig))
            return height + AudioMessageCell.insetBottom + AudioMessageCell.insetTop
        }
        return 0
    }

    open override func setupSubviews() {
        super.setupSubviews()
        messageContainerView.addSubview(audioPlayerView)
        messageContainerView.addSubview(messageLabel)
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        audioPlayerView.reset()
        messageLabel.attributedText = nil
    }

    /// Handle tap gesture on contentView and its subviews.
    open override func handleTapGesture(_ gesture: UIGestureRecognizer) {
        if audioPlayerView.didTapPlayButton(gesture) {
            delegate?.didTapPlayButton(in: self)
        } else {
            super.handleTapGesture(gesture)
        }
    }

    // MARK: - Configure Cell
    open override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
           super.apply(layoutAttributes)
           if let attributes = layoutAttributes as? MessagesCollectionViewLayoutAttributes {
               messageLabel.textInsets = attributes.messageLabelInsets
               messageLabel.messageLabelFont = attributes.messageLabelFont
           }
       }

    open override func configure(with message: MessageType, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
        super.configure(with: message, at: indexPath, and: messagesCollectionView)

        guard messagesCollectionView.messagesDataSource != nil else {
            fatalError(MessageKitError.nilMessagesDataSource)
        }

        guard let displayDelegate = messagesCollectionView.messagesDisplayDelegate else {
            fatalError(MessageKitError.nilMessagesDisplayDelegate)
        }

        let tintColor = displayDelegate.audioTintColor(for: message, at: indexPath, in: messagesCollectionView)
        audioPlayerView.setTintColor(tintColor)

        if case let .audio(audioItem) = message.kind {
            audioPlayerView.setDuration(formattedText: displayDelegate.audioProgressTextFormat(audioItem.duration,
                                                                                               for: self,
                                                                                               in: messagesCollectionView))
            configureMessageLabel(for: audioItem,
                                  with: displayDelegate,
                                  message: message,
                                  at: indexPath, in: messagesCollectionView)
        }

        setupConstraints()
        displayDelegate.configureAudioCell(self, message: message)
    }

    func configureMessageLabel(for audioItem: AudioItem,
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
               messageLabel.attributedText = audioItem.text
           }
       }

    /// Used to handle the cell's contentView's tap gesture.
    /// Return false when the contentView does not need to handle the gesture.
    open override func cellContentView(canHandle touchPoint: CGPoint) -> Bool {
        let touchPointWithoutAudioPlayerHeight = CGPoint(x: touchPoint.x,
                                                         y: touchPoint.y - audioPlayerView.frame.height)
        return messageLabel.handleGesture(touchPointWithoutAudioPlayerHeight)
    }
}
