//
//  CameraViewController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 28.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class ProfileViewController: UITableViewController {
  weak var coordinator: ProfileCoordinator?

  var contact: MRContact? {
    // This is nil if we do not have an account setup yet
    if !MRConfig.configured {
      return nil
    }
    return MRContact(id: Int(DC_CONTACT_ID_SELF))
  }

  var fingerprint: String? {
    if !MRConfig.configured {
      return nil
    }

    if let cString = dc_get_securejoin_qr(mailboxPointer, 0) {
      return String(cString: cString)
    }

    return nil
  }

  init() {
    super.init(style: .plain)
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "My Profile"
  }

  override func viewWillAppear(_: Bool) {
    navigationController?.navigationBar.prefersLargeTitles = false
    tableView.reloadData()
  }

  func displayNewChat(contactId: Int) {
    let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
    let chatVC = ChatViewController(chatId: Int(chatId))

    chatVC.hidesBottomBarWhenPushed = true
    navigationController?.pushViewController(chatVC, animated: true)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    return 2
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 2
    }

    return 0
  }

  override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = indexPath.row

    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    if indexPath.section == 0 {
      if row == 0 {
        if let fingerprint = self.fingerprint {
          cell.textLabel?.text = "Fingerprint: \(fingerprint)"
          cell.textLabel?.textAlignment = .center
        }
      }
      if row == 1 {
        if let fingerprint = self.fingerprint {
          let width: CGFloat = 130

          let frame = CGRect(origin: .zero, size: .init(width: width, height: width))
          let imageView = QRCodeView(frame: frame)
          imageView.generateCode(
            fingerprint,
            foregroundColor: .darkText,
            backgroundColor: .white
          )
          imageView.translatesAutoresizingMaskIntoConstraints = false
          // imageView.center = cell.center
          cell.addSubview(imageView)

          imageView.centerXAnchor.constraint(equalTo: cell.centerXAnchor).isActive = true
          imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor).isActive = true
          imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
          imageView.heightAnchor.constraint(equalToConstant: width).isActive = true
        }
      }
    }

    if indexPath.section == 1 {
      if row == 0 {}
    }

    return cell
  }

  override func tableView(_: UITableView, didSelectRowAt _: IndexPath) {}

  override func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    if section == 0 {
      return 80
    }

    return 20
  }

  override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath.row == 1 {
      return 150
    }

    return 46
  }

  override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)
    if section == 0 {
      let contactCell = ContactCell()
      if let contact = self.contact {
        let name = MRConfig.displayname ?? contact.name
        contactCell.backgroundColor = bg
        contactCell.nameLabel.text = name
        contactCell.emailLabel.text = contact.email
        contactCell.darkMode = false
        contactCell.selectionStyle = .none
        if let img = contact.profileImage {
          contactCell.setImage(img)
        } else {
          contactCell.setBackupImage(name: name, color: contact.color)
        }
        contactCell.setVerified(isVerified: contact.isVerified)
      } else {
        contactCell.nameLabel.text = "No Account set up"
      }
      return contactCell
    }

    let vw = UIView()
    vw.backgroundColor = bg

    return vw
  }
}
