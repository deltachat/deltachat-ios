//
//  ContactCell.swift
//  TableViewTest
//
//  Created by Alla Reinsch on 26.04.18.
//  Copyright © 2018 Alla Reinsch. All rights reserved.
//

import UIKit

class ContactCell: UITableViewCell {
  let avatar = UIView()
  let imgView = UIImageView()
  let initialsLabel = UILabel()
  let nameLabel = UILabel()
  let emailLabel = UILabel()

  var darkMode: Bool = false {
    didSet {
      if darkMode {
        contentView.backgroundColor = UIColor.darkGray
        nameLabel.textColor = UIColor.white
        emailLabel.textColor = UIColor.white
      }
    }
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)

    // configure and layout initialsLabel
    let initialsLabelSize: CGFloat = 54
    let initialsLabelCornerRadius = (initialsLabelSize - 6) / 2
    let margin: CGFloat = 15

    initialsLabel.textAlignment = NSTextAlignment.center
    initialsLabel.textColor = UIColor.white
    initialsLabel.font = UIFont.systemFont(ofSize: 22)
    initialsLabel.translatesAutoresizingMaskIntoConstraints = false
    avatar.translatesAutoresizingMaskIntoConstraints = false
    initialsLabel.widthAnchor.constraint(equalToConstant: initialsLabelSize - 6).isActive = true
    initialsLabel.heightAnchor.constraint(equalToConstant: initialsLabelSize - 6).isActive = true
    // avatar.backgroundColor = .red

    avatar.widthAnchor.constraint(equalToConstant: initialsLabelSize).isActive = true
    avatar.heightAnchor.constraint(equalToConstant: initialsLabelSize).isActive = true

    initialsLabel.backgroundColor = UIColor.green

    initialsLabel.layer.cornerRadius = initialsLabelCornerRadius
    initialsLabel.clipsToBounds = true
    avatar.addSubview(initialsLabel)
    contentView.addSubview(avatar)

    initialsLabel.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 3).isActive = true
    initialsLabel.leadingAnchor.constraint(equalTo: avatar.leadingAnchor, constant: 3).isActive = true
    initialsLabel.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: -3).isActive = true

    avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin).isActive = true
    avatar.center.y = contentView.center.y
    avatar.center.x += initialsLabelSize / 2
    avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
    avatar.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -margin).isActive = true
    initialsLabel.center = avatar.center

    let myStackView = UIStackView()
    myStackView.translatesAutoresizingMaskIntoConstraints = false
    myStackView.clipsToBounds = true

    contentView.addSubview(myStackView)
    myStackView.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: margin).isActive = true
    myStackView.centerYAnchor.constraint(equalTo: avatar.centerYAnchor).isActive = true
    myStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
    myStackView.axis = .vertical
    myStackView.addArrangedSubview(nameLabel)
    myStackView.addArrangedSubview(emailLabel)

    nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
    nameLabel.lineBreakMode = .byTruncatingTail
    nameLabel.textColor = UIColor(hexString: "2f3944")

    emailLabel.font = UIFont.systemFont(ofSize: 14)
    emailLabel.textColor = UIColor(hexString: "848ba7")
    emailLabel.lineBreakMode = .byTruncatingTail

    let img = UIImage(named: "approval")!.withRenderingMode(.alwaysTemplate)
    let imgSize: CGFloat = 25

    imgView.isHidden = true
    imgView.image = img
    imgView.bounds = CGRect(
      x: 0,
      y: 0,
      width: imgSize, height: imgSize
    )
    imgView.tintColor = Constants.primaryColor

    avatar.addSubview(imgView)

    imgView.center.x = avatar.center.x + (avatar.frame.width / 2) + imgSize - 5
    imgView.center.y = avatar.center.y + (avatar.frame.height / 2) + imgSize - 5
  }

  func setVerified(isVerified: Bool) {
    imgView.isHidden = !isVerified
  }

  func setImage(_ img: UIImage) {
    let attachment = NSTextAttachment()
    attachment.image = img

    initialsLabel.attributedText = NSAttributedString(attachment: attachment)
  }

  func setBackupImage(name: String, color: UIColor) {
    let text = Utils.getInitials(inputName: name)

    initialsLabel.textAlignment = .center
    initialsLabel.text = text

    setColor(color)
  }

  func setColor(_ color: UIColor) {
    initialsLabel.backgroundColor = color
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
