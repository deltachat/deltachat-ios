//
//  SettingsController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 26.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit
import MessageKit
import MessageInputBar

final internal class SettingsViewController: UITableViewController {
    
    // MARK: - Properties
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    let cells = ["Mock messages count", "Text Messages", "AttributedText Messages", "Photo Messages", "Video Messages", "Emoji Messages", "Location Messages", "Url Messages", "Phone Messages"]
    
    // MARK: - Picker
    
    var messagesPicker = UIPickerView()
    
    @objc func onDoneWithPickerView() {
        let selectedMessagesCount = messagesPicker.selectedRow(inComponent: 0)
        view.endEditing(false)
        tableView.reloadData()
    }
    
    @objc func dismissPickerView() {
        view.endEditing(false)
    }
    
    private func configurePickerView() {
        messagesPicker.dataSource = self
        messagesPicker.delegate = self
        messagesPicker.backgroundColor = .white
        
        messagesPicker.selectRow(0, inComponent: 0, animated: false)
    }
    
    // MARK: - Toolbar
    
    var messagesToolbar = UIToolbar()
    
    private func configureToolbar() {
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(onDoneWithPickerView))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(dismissPickerView))
        messagesToolbar.items = [cancelButton, spaceButton, doneButton]
        messagesToolbar.sizeToFit()
    }
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
            
        tableView.register(TextFieldTableViewCell.self, forCellReuseIdentifier: TextFieldTableViewCell.identifier)
        tableView.tableFooterView = UIView()
        configurePickerView()
        configureToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = false
        }
    }
    
    // MARK: - TableViewDelegate & TableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellValue = cells[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell()
        cell.textLabel?.text = cells[indexPath.row]
        
        switch cellValue {
        case "Mock messages count":
            return configureTextFieldTableViewCell(at: indexPath)
        default:
            let switchView = UISwitch(frame: .zero)
            switchView.isOn = UserDefaults.standard.bool(forKey: cellValue)
            switchView.tag = indexPath.row
            switchView.addTarget(self, action: #selector(self.switchChanged(_:)), for: .valueChanged)
            cell.accessoryView = switchView
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let cell = tableView.cellForRow(at: indexPath)
        
        cell?.contentView.subviews.forEach {
            if $0 is UITextField {
                $0.becomeFirstResponder()
            }
        }
    }
    
    // MARK: - Helper
    
    private func configureTextFieldTableViewCell(at indexPath: IndexPath) -> TextFieldTableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldTableViewCell.identifier, for: indexPath) as? TextFieldTableViewCell {
            cell.mainLabel.text = "Mock messages count:"
            
            let messagesCount = 0
            cell.textField.text = "\(messagesCount)"
            
            cell.textField.inputView = messagesPicker
            cell.textField.inputAccessoryView = messagesToolbar
            
            return cell
        }
        return TextFieldTableViewCell()
    }
    
    @objc func switchChanged(_ sender: UISwitch!) {
        let cell = cells[sender.tag]
        
        UserDefaults.standard.set(sender.isOn, forKey: cell)
    }
}

// MARK: - UIPickerViewDelegate, UIPickerViewDataSource
extension SettingsViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 100
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(row)"
    }
}
