//
//  CredentialsController.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 15.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class TextFieldCell:UITableViewCell {
    let height: CGFloat = 80
    let margin: CGFloat = 15
    let textField = UITextField()
    let label = UILabel()
    
    init(placeholder: String) {
        super.init(style: .default, reuseIdentifier: nil)

        layout()
        
        label.text = "\(placeholder):"
        textField.placeholder = placeholder
    }
    
    func layout() {
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textField)
        
        contentView.heightAnchor.constraint(equalToConstant: height).isActive = true
        
        label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin).isActive = true
        label.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.3).isActive = true
        label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
        label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin).isActive = true
        
        textField.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6).isActive = true
        textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
        textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func makeEmailCell() -> TextFieldCell {
        let emailCell = TextFieldCell(placeholder: "Email")
        
        emailCell.textField.textContentType = UITextContentType.emailAddress
        emailCell.textField.keyboardType = .emailAddress
        // switch off quicktype
        emailCell.textField.autocorrectionType = .no
        emailCell.textField.autocapitalizationType = .none
        
        return emailCell
    }
    
    static func makePasswordCell() -> TextFieldCell {
        let passwordCell = TextFieldCell(placeholder: "Password")
        
        passwordCell.textField.textContentType = UITextContentType.password
        passwordCell.textField.isSecureTextEntry = true
        
        return passwordCell
    }
}


class ButtonCell:UITableViewCell {
    let height: CGFloat = 80
    let margin: CGFloat = 15
    let button = UIButton(type: UIButtonType.system)
    
    func enable() {
        button.isEnabled = true
    }
    
    func disable() {
        button.isEnabled = false
    }
    
    init() {
        super.init(style: .default, reuseIdentifier: nil)

        button.setTitle("Save Account", for: .normal)
        
        layout()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout() {
        contentView.heightAnchor.constraint(equalToConstant: height).isActive = true
        
        button.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(button)
        
        button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin).isActive = true
        button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
        button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin).isActive = true
    }
}

class CredentialsController: UITableViewController {
    let emailCell = TextFieldCell.makeEmailCell()
    let passwordCell = TextFieldCell.makePasswordCell()
    let buttonCell = ButtonCell()
    
    var model:(email:String, password:String) = ("", "") {
        didSet {
            if (model.email.contains("@") && model.email.count >= 3 && !model.password.isEmpty) {
                buttonCell.enable()
            } else {
                buttonCell.disable()
            }
        }
    }
    
    let cells:[UITableViewCell]
    
    init() {
        cells = [emailCell, passwordCell, buttonCell]

        super.init(style: .plain)
        
        emailCell.textField.addTarget(self, action: #selector(CredentialsController.emailTextChanged), for: UIControlEvents.editingChanged)
        passwordCell.textField.addTarget(self, action: #selector(CredentialsController.passwordTextChanged), for: UIControlEvents.editingChanged)
        buttonCell.button.addTarget(self, action: #selector(CredentialsController.saveAccountButtonPressed), for: .touchUpInside)
        
        buttonCell.disable()
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
        
        title = "Email Account"
        
        // auto-size table view cells
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        
        tableView.separatorStyle = .none
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
