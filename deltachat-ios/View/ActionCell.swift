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

  private lazy var actionLabel: UILabel = {
    let label = UILabel()
    label.text = actionTitle
    label.textColor = UIColor.systemBlue
    return label
  }()

  // use this constructor if cell won't be reused
  init(title: String) {
    actionTitle = title
    super.init(style: .default, reuseIdentifier: nil)
    setupSubviews()
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupSubviews()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    // Initialization code
  }

  override func setSelected(_: Bool, animated _: Bool) {
    // no selection style ...
  }

  private func setupSubviews() {
    contentView.addSubview(actionLabel)
    actionLabel.translatesAutoresizingMaskIntoConstraints = false
    actionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 0).isActive = true
    actionLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
  }
}
