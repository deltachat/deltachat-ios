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
	private var selectedIndex: Int {
		didSet {
			print(selectedIndex)
		}
	}

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

	init(title: String, options: [String], selectedOption: String) {
		self.options = options
		selectedIndex = options.index(of: selectedOption)!
		backupIndex = selectedIndex
		super.init(style: .grouped)
		self.title = title
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


enum SecurityType {
	case IMAPSecurity
	case SMTPSecurity
}

enum SecurityValue: String {
	case TLS = "SSL / TLS"
	case STARTTLS = "STARTTLS"
	case PLAIN = "OFF"
}

class SecurityConverter {

	static func convert(type: SecurityType, test value: SecurityValue) -> Int {
		switch type {
		case .IMAPSecurity:
			switch value {
			case .STARTTLS:
				return 0x100
			case .TLS:
				return 0x200
			case .PLAIN:
				return 0x400
			}
		case .SMTPSecurity:
			switch value{
			case .STARTTLS:
				return 0x10000
			case .TLS:
				return 0x20000
			case .PLAIN:
				return 0x40000
			}
		}
	}

	static func convert(type: SecurityType, hex value: Int) -> String {
		switch type {
		case .IMAPSecurity:
			switch value {
			case 0:
				return "Automatic"
			case 0x100:
				return "STARTTLS"
			case 0x200:
				return "SSL / TLS"
			case 0x300:
				return "OFF"
			case  0x400:
				return "OFF"
			default:
				return "Undefined"
			}
		case .SMTPSecurity:
			switch value {
			case 0:
				return "Automatic"
			case 0x10000:
					return "STARTTLS"
				case 0x20000:
				return "SSL / TLS"
				case  0x40000:
				return "OFF"
				default:
				return "Undefined"
			}
		}
	}
}
