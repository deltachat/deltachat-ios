//
//  NewChatViewController.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 21.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import ALCameraViewController
import Contacts
import UIKit

protocol ChatDisplayer: class {
  func displayNewChat(contactId: Int)
  func displayChatForId(chatId: Int)
}

class NewChatViewController: UITableViewController {
  var contactIds: [Int] = Utils.getContactIds()
  weak var chatDisplayer: ChatDisplayer?

  var syncObserver: Any?
  var hud: ProgressHud?

  let deviceContactHandler = DeviceContactsHandler()
  var deviceContactAccessGranted: Bool = false {
    didSet {
      tableView.reloadData()
    }
  }

  init() {
    super.init(style: .grouped)
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = "New Chat"
    navigationController?.navigationBar.prefersLargeTitles = true

    let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(NewChatViewController.cancelButtonPressed))
    navigationItem.rightBarButtonItem = cancelButton

    deviceContactHandler.importDeviceContacts(delegate: self)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    contactIds = Utils.getContactIds()
    tableView.reloadData()

    let nc = NotificationCenter.default
    syncObserver = nc.addObserver(
      forName: dcNotificationSecureJoinerProgress,
      object: nil,
      queue: nil
    ) {
      notification in
      if let ui = notification.userInfo {
        if ui["error"] as! Bool {
          self.hud?.error(ui["errorMessage"] as? String)
        } else if ui["done"] as! Bool {
          self.hud?.done()
        } else {
          self.hud?.progress(ui["progress"] as! Int)
        }
      }
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    let nc = NotificationCenter.default
    if let syncObserver = self.syncObserver {
      nc.removeObserver(syncObserver)
    }
  }

  @objc func cancelButtonPressed() {
    dismiss(animated: true, completion: nil)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    return 1
  }

  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    return contactIds.count + 3
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = indexPath.row
    if row == 0 {
      // new group row
      let cell: UITableViewCell
      if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
        cell = c
      } else {
        cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
      }
      cell.textLabel?.text = "New Group"
      cell.textLabel?.textColor = view.tintColor

      return cell
    }
    if row == 1 {
      // new contact row
      let cell: UITableViewCell
      if let c = tableView.dequeueReusableCell(withIdentifier: "scanGroupCell") {
        cell = c
      } else {
        cell = UITableViewCell(style: .default, reuseIdentifier: "scanGroupCell")
      }
      cell.textLabel?.text = "Scan Group QR Code"
      cell.textLabel?.textColor = view.tintColor

      return cell
    }

    if row == 2 {
      // new contact row
      let cell: UITableViewCell
      if let c = tableView.dequeueReusableCell(withIdentifier: "newContactCell") {
        cell = c
      } else {
        cell = UITableViewCell(style: .default, reuseIdentifier: "newContactCell")
      }
      cell.textLabel?.text = "New Contact"
      cell.textLabel?.textColor = view.tintColor

      return cell
    }

    let cell: ContactCell
    if let c = tableView.dequeueReusableCell(withIdentifier: "contactCell") as? ContactCell {
      cell = c
    } else {
      cell = ContactCell(style: .default, reuseIdentifier: "contactCell")
    }

    let contactRow = row - 3

    let contact = MRContact(id: contactIds[contactRow])
    cell.nameLabel.text = contact.name
    cell.emailLabel.text = contact.email
    cell.initialsLabel.text = Utils.getInitials(inputName: contact.name)
    cell.setColor(contact.color)

    cell.accessoryType = .detailDisclosureButton
    return cell
  }

  override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
    let row = indexPath.row
    if row == 0 {
      let newGroupController = NewGroupViewController()
      navigationController?.pushViewController(newGroupController, animated: true)
    }
    if row == 1 {
      if UIImagePickerController.isSourceTypeAvailable(.camera) {
        let controller = QrCodeReaderController()
        controller.delegate = self
        present(controller, animated: true, completion: nil)

      } else {
        let alert = UIAlertController(title: "Camera is not available", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
          self.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
      }
    }
    if row == 2 {
      let newContactController = NewContactController()
      navigationController?.pushViewController(newContactController, animated: true)
    }
    if row > 2 {
      let contactIndex = row - 3
      let contactId = contactIds[contactIndex]
      dismiss(animated: false) {
        self.chatDisplayer?.displayNewChat(contactId: contactId)
      }
    }
  }

  override func tableView(_: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    let row = indexPath.row
    if row > 2 {
      let contactIndex = row - 3
      let contactId = contactIds[contactIndex]
      // let newContactController = NewContactController(contactIdForUpdate: contactId)
      // navigationController?.pushViewController(newContactController, animated: true)
      let contactProfileController = ContactProfileViewController(contactId: contactId)
      navigationController?.pushViewController(contactProfileController, animated: true)
    }
  }
}

extension NewChatViewController: QrCodeReaderDelegate {
  func handleQrCode(_ code: String) {
    logger.info("decoded: \(code)")

    let check = dc_check_qr(mailboxPointer, code)!
    logger.info("got ver: \(check)")

    if dc_lot_get_state(check) == DC_QR_ASK_VERIFYGROUP {
      hud = ProgressHud("Synchronizing Account", in: view)
      DispatchQueue.global(qos: .userInitiated).async {
        let id = dc_join_securejoin(mailboxPointer, code)

        DispatchQueue.main.async {
          self.dismiss(animated: true) {
            self.chatDisplayer?.displayChatForId(chatId: Int(id))
          }
        }
      }
    } else {
      let alert = UIAlertController(title: "Not a valid group QR Code", message: code, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
        self.dismiss(animated: true, completion: nil)
      }))
      present(alert, animated: true, completion: nil)
    }

    dc_lot_unref(check)
  }
}

extension NewChatViewController: DeviceContactsDelegate {
  func accessGranted() {
    deviceContactAccessGranted = false
  }

  func accessDenied() {
    deviceContactAccessGranted = false
  }

  private func showSettingsAlert(_ completionHandler: @escaping (_ accessGranted: Bool) -> Void) {
    let alert = UIAlertController(title: nil, message: "This app requires access to Contacts to proceed. Would you like to open settings and grant permission to contacts?", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
      completionHandler(false)
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    })
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
      completionHandler(false)
    })
    present(alert, animated: true)
  }
}

protocol DeviceContactsDelegate {
  func accessGranted()
  func accessDenied()
}
