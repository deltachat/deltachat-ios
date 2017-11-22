//
//  CredentialsController.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 15.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class TextFieldCell:UITableViewCell {
    let textField = UITextField()
    
    init(description: String, placeholder: String) {
        super.init(style: .value1, reuseIdentifier: nil)
        
        textLabel?.text = "\(description):"
        contentView.addSubview(textField)

        textField.translatesAutoresizingMaskIntoConstraints = false
        
        // see: https://stackoverflow.com/a/35903650
        // this makes the textField respect the trailing margin of
        // the table view cell
        let margins = contentView.layoutMarginsGuide
        let trailing = margins.trailingAnchor
        textField.trailingAnchor.constraint(equalTo: trailing).isActive = true
        textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        textField.textAlignment = .right

        textField.placeholder = placeholder
        
        selectionStyle = .none
        
        textField.enablesReturnKeyAutomatically = true
    }
    
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        if selected {
            textField.becomeFirstResponder()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func makeEmailCell() -> TextFieldCell {
        let emailCell = TextFieldCell(description: "Email", placeholder: "you@example.com")
        
        emailCell.textField.keyboardType = .emailAddress
        // switch off quicktype
        emailCell.textField.autocorrectionType = .no
        emailCell.textField.autocapitalizationType = .none
        
        return emailCell
    }
    
    static func makePasswordCell() -> TextFieldCell {
        let passwordCell = TextFieldCell(description: "Password", placeholder: "your IMAP password")
        
        passwordCell.textField.textContentType = UITextContentType.password
        passwordCell.textField.isSecureTextEntry = true
        
        return passwordCell
    }
    
    static func makeNameCell() -> TextFieldCell {
        let nameCell = TextFieldCell(description: "Name", placeholder: "new contacts nickname")
        
        nameCell.textField.autocapitalizationType = .words
        nameCell.textField.autocorrectionType = .no
        // .namePhonePad doesn't support autocapitalization
        // see: https://stackoverflow.com/a/36365399
        // therefore we use .default to capitalize the first character of the name
        nameCell.textField.keyboardType = .default
        
        return nameCell
    }
}

class CredentialsController: UITableViewController {
    let emailCell = TextFieldCell.makeEmailCell()
    let passwordCell = TextFieldCell.makePasswordCell()
    var doneButton:UIBarButtonItem?
    
    func readyForLogin() -> Bool {
        return Utils.isValid(model.email) && !model.password.isEmpty
    }
    
    var model:(email:String, password:String) = ("", "") {
        didSet {
            if readyForLogin() {
                doneButton?.isEnabled = true
            } else {
                doneButton?.isEnabled = false
            }
        }
    }
    
    let cells:[UITableViewCell]
    
    init() {
        cells = [emailCell, passwordCell]

        super.init(style: .grouped)
        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(CredentialsController.saveAccountButtonPressed))
        doneButton?.isEnabled = false
        navigationItem.rightBarButtonItem = doneButton
        
        emailCell.textField.addTarget(self, action: #selector(CredentialsController.emailTextChanged), for: UIControlEvents.editingChanged)
        passwordCell.textField.addTarget(self, action: #selector(CredentialsController.passwordTextChanged), for: UIControlEvents.editingChanged)
        
        emailCell.textField.textContentType = UITextContentType.emailAddress
        emailCell.textField.delegate = self
        passwordCell.textField.delegate = self
        emailCell.textField.returnKeyType = .next
        passwordCell.textField.returnKeyType = .done
    }
    
    override func viewDidAppear(_ animated: Bool) {
        emailCell.textField.becomeFirstResponder()
    }
    
    @objc func emailTextChanged() {
        let emailText = emailCell.textField.text ?? ""
        
        model.email = emailText
    }
    
    @objc func passwordTextChanged() {
        let passwordText = passwordCell.textField.text ?? ""
        
        model.password = passwordText
    }
    
    @objc func saveAccountButtonPressed() {
        dismiss(animated: true) {
            initCore(withCredentials: true, email: self.model.email, password: self.model.password)
            AppDelegate.appCoordinator.setupInnerViewControllers()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Account"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        
        return cells[row]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension CredentialsController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailCell.textField {
            if let emailText = emailCell.textField.text {
                // only jump to next field if valid email
                if Utils.isValid(emailText) {
                    passwordCell.textField.becomeFirstResponder()
                }
            }
        }
        if textField == passwordCell.textField {
            if readyForLogin() {
                self.saveAccountButtonPressed()
            }
        }
        return true
    }
}
