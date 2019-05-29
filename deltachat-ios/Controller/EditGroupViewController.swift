//
//  EditGroupViewController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 29.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class EditGroupViewController: UITableViewController {

	weak var coordinator: EditGroupCoordinator?

	private let chat: MRChat

	lazy var groupNameCell: GroupLabelCell = {
		let cell = GroupLabelCell(style: .default, reuseIdentifier: nil)
		cell.onTextChanged = groupNameEdited(_:)
		return cell
	}()

	lazy var doneButton: UIBarButtonItem = {
		let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveContactButtonPressed))
		button.isEnabled = false
		return button
	}()

	lazy var cancelButton: UIBarButtonItem = {
		let button = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
		return button
	}()

	init(chat: MRChat) {
		self.chat = chat
		super.init(style: .grouped)
		groupNameCell.inputField.text = chat.name
		groupNameCell.groupBadge.setText(chat.name)
		groupNameCell.groupBadge.setColor(chat.color)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.rightBarButtonItem = doneButton
		navigationItem.leftBarButtonItem = cancelButton
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return groupNameCell
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	@objc func saveContactButtonPressed() {
		let newName = groupNameCell.getGroupName()
		dc_set_chat_name(mailboxPointer, UInt32(chat.id), newName)
		coordinator?.navigateBack()
	}

	@objc func cancelButtonPressed() {
		coordinator?.navigateBack()
	}

	private func groupNameEdited(_ newName: String) {
		doneButton.isEnabled = true
	}
}
