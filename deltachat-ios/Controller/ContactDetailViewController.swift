//
//  TableViewController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 22.05.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class ContactDetailViewController: UITableViewController {
  weak var coordinator: ContactDetailCoordinator?

  let contactId: Int

  var contact: MRContact {
    return MRContact(id: contactId)
  }

  init(contactId: Int) {
    self.contactId = contactId
    super.init(style: .plain)
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Info"
  }

  override func viewWillAppear(_: Bool) {
    navigationController?.navigationBar.prefersLargeTitles = false
    tableView.reloadData()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    return 1
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 3
    }

    return 0
  }

  override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = indexPath.row

    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

    let settingsImage = #imageLiteral(resourceName: "baseline_settings_black_18pt").withRenderingMode(.alwaysTemplate)
    cell.imageView?.image = settingsImage
    cell.imageView?.tintColor = UIColor.clear

    if row == 0 {
      cell.textLabel?.text = "Settings"
      cell.imageView?.tintColor = UIColor.gray
    }
    if row == 1 {
      cell.textLabel?.text = "Edit name"
    }

    if row == 2 {
      cell.textLabel?.text = "New chat"
    }
    return cell
  }

  override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    let row = indexPath.row

    if row == 0 {
      let alert = UIAlertController(title: "Not implemented", message: "Settings are not implemented yet.", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
      present(alert, animated: true, completion: nil)
    }
    if row == 1 {
      let newContactController = NewContactController(contactIdForUpdate: contactId)
      navigationController?.pushViewController(newContactController, animated: true)
    }
    if row == 2 {
      displayNewChat(contactId: contactId)
    }
  }

  override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
    return 80
  }

  override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)
    if section == 0 {
      let contactCell = ContactCell()
      contactCell.backgroundColor = bg
      contactCell.nameLabel.text = contact.name
      contactCell.emailLabel.text = contact.email
      contactCell.darkMode = false
      contactCell.selectionStyle = .none
      if let img = contact.profileImage {
        contactCell.setImage(img)
      } else {
        contactCell.setBackupImage(name: contact.name, color: contact.color)
      }
      contactCell.setVerified(isVerified: contact.isVerified)
      return contactCell
    }

    let vw = UIView()
    vw.backgroundColor = bg

    return vw
  }

  private func displayNewChat(contactId: Int) {
    let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
    coordinator?.showChat(chatId: Int(chatId))
  }
}
