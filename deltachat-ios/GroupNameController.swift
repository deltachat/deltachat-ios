//
//  GroupNameController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 20.07.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class GroupNameController: UIViewController {
  var doneButton: UIBarButtonItem!
  let groupNameTextField = UITextField()
  let contactIdsForGroup: Set<Int>
  var groupName = "" {
    didSet {
      if groupName.isEmpty {
        logger.info("empty")
        doneButton.isEnabled = false
      } else {
        logger.info("something")
        doneButton.isEnabled = true
      }
    }
  }

  init(contactIdsForGroup: Set<Int>) {
    self.contactIdsForGroup = contactIdsForGroup
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func layoutTextField() {
    groupNameTextField.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(groupNameTextField)
    groupNameTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    groupNameTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
    groupNameTextField.placeholder = "Group Name"
    groupNameTextField.becomeFirstResponder()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Group Name"
    groupNameTextField.delegate = self
    layoutTextField()

    doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didPressDoneButton))
    navigationItem.rightBarButtonItem = doneButton
    doneButton.isEnabled = false
  }

  @objc func didPressDoneButton() {
    logger.info("Done Button pressed")
    let groupChatId = dc_create_group_chat(mailboxPointer, 0, groupName)
    for contactId in contactIdsForGroup {
      let success = dc_add_contact_to_chat(mailboxPointer, groupChatId, UInt32(contactId))
      if success == 1 {
        logger.info("successfully added \(contactId) to group \(groupName)")
      } else {
        // FIXME:
        fatalError("failed to add \(contactId) to group \(groupName)")
      }
    }
    groupNameTextField.resignFirstResponder()
    let root = navigationController?.presentingViewController
    navigationController?.dismiss(animated: true) {
      let chatVC = ChatViewController(chatId: Int(groupChatId))
      if let navigationRoot = root as? UINavigationController {
        navigationRoot.pushViewController(chatVC, animated: true)
      }
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

extension GroupNameController: UITextFieldDelegate {
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    let text = (textField.text! as NSString).replacingCharacters(in: range, with: string)
    groupName = text

    return true
  }
}
