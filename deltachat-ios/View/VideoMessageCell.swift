//
//  VideoMessageCell.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 21.06.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit
import MessageKit

class VideoMessageCell: MediaMessageCell {
	/// Responsible for setting up the constraints of the cell's subviews.
	override func setupConstraints() {
		super.setupConstraints()
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.widthAnchor.constraint(equalToConstant: 100).isActive = true
		imageView.heightAnchor.constraint(equalToConstant: 100).isActive = true

	}

	func configure(with message: MessageType, videoUrl url: URL?, at indexPath: IndexPath, and messagesCollectionView: MessagesCollectionView) {
		super.configure(with: message, at: indexPath, and: messagesCollectionView)

		if let url = url {
			
			let thumbnail = Utils.generateThumbnailFromVideo(url: url)
			imageView.image = thumbnail



		}

	}

	override func layoutMessageContainerView(with attributes: MessagesCollectionViewLayoutAttributes) {
		var origin: CGPoint = .zero
		let videoMessageCellWidth: CGFloat = 150
		let videoMessageCellHeight: CGFloat = 150


		switch attributes.avatarPosition.vertical {
		case .messageBottom:
			origin.y = attributes.size.height
				- attributes.messageContainerPadding.bottom
				- attributes.cellBottomLabelSize.height
				- attributes.messageBottomLabelSize.height
				- videoMessageCellHeight
				- attributes.messageContainerPadding.top
		case .messageCenter:
			if attributes.avatarSize.height > videoMessageCellHeight {
				let messageHeight = videoMessageCellHeight + 10 // attributes.messageContainerPadding.vertical
				origin.y = (attributes.size.height / 2) - (messageHeight / 2)
			} else {
				fallthrough
			}
		default:
			if attributes.accessoryViewSize.height > videoMessageCellHeight {
				let messageHeight =  videoMessageCellHeight + 10 //attributes.messageContainerPadding.vertical
				origin.y = (attributes.size.height / 2) - (messageHeight / 2)
			} else {
				origin.y = attributes.cellTopLabelSize.height + attributes.messageTopLabelSize.height + attributes.messageContainerPadding.top
			}
		}

		let avatarPadding = attributes.avatarLeadingTrailingPadding
		switch attributes.avatarPosition.horizontal {
		case .cellLeading:
			origin.x = attributes.avatarSize.width + attributes.messageContainerPadding.left + avatarPadding
		case .cellTrailing:
			origin.x = attributes.frame.width - attributes.avatarSize.width - videoMessageCellWidth - attributes.messageContainerPadding.right - avatarPadding
		case .natural:
			break
			//fatalError(MessageKitError.avatarPositionUnresolved)
		}




		messageContainerView.frame = CGRect(origin: origin, size: CGSize(width: videoMessageCellWidth, height: videoMessageCellHeight))
	}
}
