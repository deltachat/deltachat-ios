//
//  AccountSetupController.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 02.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

class AccountSetupController: UITableViewController {
  
  init() {
    super.init(style: .grouped)
    tableView.allowsSelection = false
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
      super.viewDidLoad()

    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Login", style: .done, target: self, action: #selector(loginButtonPressed))
  }

    // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
      // #warning Incomplete implementation, return the number of sections
      return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      // #warning Incomplete implementation, return the number of rows
    if section == 0 {
      return 2
    } else {
      return 0
    }
}
  
    @objc func loginButtonPressed() {
        print("login button pressed")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row
        let cell:UITableViewCell
        if row == 0 {
            let inputCell = InputTableViewCell()
            inputCell.textLabel?.text = "Email"
            inputCell.inputField.placeholder = "user@example.com"
            cell = inputCell
        } else {
            let pwCell = PasswordInputCell()
            pwCell.textLabel?.text = "Password"
            pwCell.inputField.placeholder = "Required"
            cell = pwCell
        }
        return cell
    }
}


class InputTableViewCell: UITableViewCell {
    
    lazy var inputField: UITextField = {
        let textField = UITextField()
        return textField
    }()
    
    
    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.addSubview(inputField)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        
        inputField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        inputField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        inputField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 100).isActive = true
        inputField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
    }
}

class PasswordInputCell: UITableViewCell {
    
    lazy var inputField: UITextField = {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        return textField
    }()
    
    // TODO: to add Eye-icon -> uncomment -> add to inputField.rightView
    /*
    lazy var makeVisibleIcon: UIImageView = {
       let view = UIImageView(image: )
        return view
    }()
    */
    
    init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.addSubview(inputField)
        inputField.translatesAutoresizingMaskIntoConstraints = false
        
        inputField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 0).isActive = true
        inputField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5).isActive = true
        inputField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
        inputField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 100).isActive = true
        inputField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0).isActive = true
    }
}
