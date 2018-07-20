//
//  GroupNameController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 20.07.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class GroupNameController: UIViewController {
    var doneButton:UIBarButtonItem!
    let groupNameTextField = UITextField()
    var groupName = "" {
        didSet {
            if groupName.isEmpty {
                print("empty")
                doneButton.isEnabled = false
            } else {
                print("something")
                doneButton.isEnabled = true
            }
        }
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
        
        doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
        navigationItem.rightBarButtonItem = doneButton
        doneButton.isEnabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension GroupNameController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = (textField.text! as! NSString).replacingCharacters(in: range, with: string)
        groupName = text
        
        return true
    }
    
    
    
}
