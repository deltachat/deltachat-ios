//
//  IntitialsBadge.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 07.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

// shall be used for contactCell/ groups

class InitialsBadge: UIView {
  private lazy var label: UILabel = {
    let label = UILabel()
    label.textAlignment = NSTextAlignment.center
    label.textColor = UIColor.white
    label.font = UIFont.systemFont(ofSize: 22)
    // label.adjustsFontSizeToFitWidth = true
    return label
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupSubviews()

    layer.cornerRadius = frame.width / 2
    clipsToBounds = true
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupSubviews() {
    addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2).isActive = true
    label.topAnchor.constraint(equalTo: topAnchor, constant: 2).isActive = true
    label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2).isActive = true
    label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2).isActive = true
  }

  func setColor(_ color: UIColor) {
    backgroundColor = color
  }

  func setText(_ text: String) {
    let initials = Utils.getInitials(inputName: text)
    label.text = initials
  }
}
