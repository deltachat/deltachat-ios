//
//  CredentialsController.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 15.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import UIKit

class TextEntryCell:UITableViewCell {
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
        
        contentView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        
        label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: margin).isActive = true
        label.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.3).isActive = true
        label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
        label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin).isActive = true
        
        textField.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.6).isActive = true
        textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -margin).isActive = true
        textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: margin).isActive = true
        textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -margin).isActive = true
        

        
        label.layer.borderWidth = 1
        textField.layer.borderWidth = 1
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class CredentialsController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.estimatedRowHeight = 100
        
        
        self.tableView.register(TextEntryCell.self, forCellReuseIdentifier: String(describing: TextEntryCell.self))
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row

        let cell:TextEntryCell
        if row == 0 {
            cell = TextEntryCell(placeholder: "Email")
        } else {
            cell = TextEntryCell(placeholder: "Password")
            cell.textField.textContentType = UITextContentType.password
            cell.textField.isSecureTextEntry = true
        }
        
        return cell
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
