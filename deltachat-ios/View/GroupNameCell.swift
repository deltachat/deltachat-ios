//
//  GroupNameCell.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 06.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class GroupLabelCell: UITableViewCell {
  private let groupBadgeSize: CGFloat = 60
  var groupNameUpdated: ((String) -> Void)? // use this callback to update editButton in navigationController

  lazy var groupBadge: InitialsLabel = {
    let badge = InitialsLabel(size: groupBadgeSize)
    badge.set(color: UIColor.lightGray)
    return badge
  }()

  lazy var inputField: UITextField = {
    let textField = UITextField()
    textField.placeholder = "Group Name"
    textField.borderStyle = .none
    textField.becomeFirstResponder()
    textField.autocorrectionType = .no
    textField.addTarget(self, action: #selector(nameFieldChanged), for: .editingChanged)
    return textField
  }()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupSubviews()
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupSubviews() {
    contentView.addSubview(groupBadge)
    groupBadge.translatesAutoresizingMaskIntoConstraints = false

    groupBadge.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: 0).isActive = true
    groupBadge.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor, constant: 5).isActive = true
    groupBadge.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor, constant: -5).isActive = true
    groupBadge.widthAnchor.constraint(equalToConstant: groupBadgeSize).isActive = true
    groupBadge.heightAnchor.constraint(equalToConstant: groupBadgeSize).isActive = true

    contentView.addSubview(inputField)
    inputField.translatesAutoresizingMaskIntoConstraints = false

    inputField.leadingAnchor.constraint(equalTo: groupBadge.trailingAnchor, constant: 15).isActive = true
    inputField.heightAnchor.constraint(equalToConstant: 45).isActive = true
    inputField.centerYAnchor.constraint(equalTo: groupBadge.centerYAnchor, constant: 0).isActive = true
    inputField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor, constant: 0).isActive = true
  }

  @objc func nameFieldChanged() {
    let groupName = inputField.text ?? ""
    groupBadge.set(name: groupName)
    groupNameUpdated?(groupName)
  }
}
