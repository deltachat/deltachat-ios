//
//  SecuritySettingsController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 15.05.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class SecuritySettingsController: UITableViewController {

	private var options: [String]
	private var selectedIndex: Int
	private var backupIndex: Int

	var onDismiss: ((String) -> Void)?

	private var resetButton: UIBarButtonItem!

	private var staticCells: [UITableViewCell] {
		return options.map {
			let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
			cell.textLabel?.text = $0
			cell.selectionStyle = .none
			return cell
		}
	}

	init(options: [String], selectedOption: String) {
		self.options = options
		selectedIndex = options.index(of: selectedOption)!
		backupIndex = selectedIndex
		super.init(style: .grouped)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		resetButton = UIBarButtonItem(title: "Reset", style: .done, target: self, action: #selector(resetButtonPressed))
		resetButton.isEnabled = false
		navigationItem.rightBarButtonItem = resetButton
	}

	override func viewWillDisappear(_ animated: Bool) {
		let selectedOption = options[selectedIndex]
		onDismiss?(selectedOption)
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return options.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = staticCells[indexPath.row]
		if selectedIndex == indexPath.row {
			cell.accessoryType = .checkmark
		} else {
			cell.accessoryType = .none
		}
		return cell
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		// uselect old
		if let cell = tableView.cellForRow(at: IndexPath(item: selectedIndex, section: 0)) {
			cell.accessoryType = .none
		}
		// select new
		if let cell = tableView.cellForRow(at: indexPath) {
			cell.accessoryType = .checkmark
		}
		selectedIndex = indexPath.row
		resetButton.isEnabled = true
	}

	@objc func resetButtonPressed() {
		selectedIndex = backupIndex
		tableView.reloadData()
	}

}
