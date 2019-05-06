//
//  GroupNameController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 20.07.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class GroupNameController: UITableViewController {

	weak var coordinator: GroupNameCoordinator?

	var groupName: String = ""

  var doneButton: UIBarButtonItem!
  let contactIdsForGroup: Set<Int>

  init(contactIdsForGroup: Set<Int>) {
    self.contactIdsForGroup = contactIdsForGroup
    super.init(style: .grouped)
  }

  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }


  override func viewDidLoad() {
    super.viewDidLoad()
    title = "New Group"
		doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonPressed))
    navigationItem.rightBarButtonItem = doneButton
		tableView.bounces = false
    doneButton.isEnabled = false
		tableView.register(GroupLabelCell.self, forCellReuseIdentifier: "groupLabelCell")
		// setupSubviews()

	}

  @objc func doneButtonPressed() {
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


	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
		
	}


	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let section = indexPath.section
		let row = indexPath.row

		if section == 0 {
		}

		let cell = tableView.dequeueReusableCell(withIdentifier: "groupLabelCell", for: indexPath) as! GroupLabelCell
		cell.groupNameUpdated = updateGroupNamae

		return cell
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	private func updateGroupNamae(name: String) {
		groupName = name
		doneButton.isEnabled = name.containsCharacters()
	}
}



class GroupLabelCell: UITableViewCell {

	private let groupBadgeSize: CGFloat = 60
	var groupNameUpdated: ((String) -> ())?

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
		textField.addTarget(self, action: #selector(nameFieldChanged), for: .editingChanged)
		return textField
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupSubviews()
	}

	required init?(coder aDecoder: NSCoder) {
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




