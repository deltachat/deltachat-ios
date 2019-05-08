//
//  ActionCell.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 17.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

// a cell with a centered label in system blue

class ActionCell: UITableViewCell {
  var actionTitle: String? {
    didSet {
      actionLabel.text = actionTitle
    }
  }

  var actionColor: UIColor? {
    didSet {
      actionLabel.textColor = actionColor ?? UIColor.systemBlue
    }
  }

  private lazy var actionLabel: UILabel = {
    let label = UILabel()
    label.text = actionTitle
    label.textColor = UIColor.systemBlue
    return label
  }()

  // use this constructor if cell won't be reused
  convenience init(title: String) {
    self.init(style: .default, reuseIdentifier: nil)
    actionTitle = title
    selectionStyle = .none
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupSubviews()
    selectionStyle = .none
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }

  private func setupSubviews() {
    contentView.addSubview(actionLabel)
    actionLabel.translatesAutoresizingMaskIntoConstraints = false
    actionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 0).isActive = true
    actionLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
  }
}
