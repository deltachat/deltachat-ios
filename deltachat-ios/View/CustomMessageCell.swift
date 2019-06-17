//
import MessageKit
//  CustomCell.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//
import UIKit


open class CustomMessageCell: UICollectionViewCell {
  let label = UILabel()

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setupSubviews()
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setupSubviews()
  }

  open func setupSubviews() {
    contentView.addSubview(label)
    label.textAlignment = .center
    label.font = UIFont.italicSystemFont(ofSize: 13)
  }

  open override func layoutSubviews() {
    super.layoutSubviews()
    label.frame = contentView.bounds
  }

  open func configure(with message: MessageType, at _: IndexPath, and _: MessagesCollectionView) {
    // Do stuff
    switch message.kind {
    case let .custom(data):
      guard let systemMessage = data as? String else { return }
      label.text = systemMessage
    default:
      break
    }
  }
}

