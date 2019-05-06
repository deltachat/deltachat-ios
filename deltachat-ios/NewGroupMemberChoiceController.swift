//
//  NewGroupMemberChoiceController.swift
//  deltachat-ios
//
//  Created by Alla Reinsch on 24.07.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

/*
 class ViewController: UIViewController {
 override func viewDidLoad() {
   super.viewDidLoad()

   let n: CGFloat = 150
   let l: CGFloat = 40
   let generalView = UIView()
   let square = UIView()
   square.layer.cornerRadius = n / 2
   let nameLabel = UILabel()
   nameLabel.text = "Alic Doe"
   square.translatesAutoresizingMaskIntoConstraints = false
   nameLabel.translatesAutoresizingMaskIntoConstraints = false
   generalView.translatesAutoresizingMaskIntoConstraints = false

   view.addSubview(generalView)
   view.addSubview(square)
   view.addSubview(nameLabel)
   generalView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
   generalView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
   square.centerXAnchor.constraint(equalTo: generalView.centerXAnchor).isActive = true
   square.centerYAnchor.constraint(equalTo: generalView.centerYAnchor).isActive = true
   nameLabel.topAnchor.constraint(equalTo: square.bottomAnchor).isActive = true
   nameLabel.leadingAnchor.constraint(equalTo: square.leadingAnchor).isActive = true

   square.widthAnchor.constraint(equalToConstant: n).isActive = true
   square.heightAnchor.constraint(equalToConstant: n).isActive = true
   nameLabel.widthAnchor.constraint(equalToConstant: n).isActive = true
   nameLabel.heightAnchor.constraint(equalToConstant: l).isActive = true
   generalView.widthAnchor.constraint(equalToConstant: n).isActive = true
   generalView.heightAnchor.constraint(equalToConstant: n + l).isActive = true
   square.backgroundColor = UIColor.blue
   nameLabel.backgroundColor = UIColor.green
   generalView.backgroundColor = UIColor.cyan
   nameLabel.textColor = UIColor.white
   nameLabel.font = UIFont.systemFont(ofSize: 14)

   let deleteButton = UIButton()
   deleteButton.translatesAutoresizingMaskIntoConstraints = false

   let sin45: CGFloat = 0.7071
   let squareRadius: CGFloat = n / 2
   let deltaX: CGFloat = sin45 * squareRadius
   let deltaY: CGFloat = squareRadius - deltaX
   let deleteButtonWidth: CGFloat = deltaX
   let deleteButtonHeight: CGFloat = deltaX
   deleteButton.layer.cornerRadius = deleteButtonWidth / 2

   deleteButton.widthAnchor.constraint(equalToConstant: deleteButtonWidth).isActive = true
   deleteButton.heightAnchor.constraint(equalToConstant: deleteButtonHeight).isActive = true
   deleteButton.backgroundColor = UIColor.gray
   deleteButton.clipsToBounds = true

   deleteButton.layer.borderWidth = 3
   deleteButton.layer.borderColor = UIColor.white.cgColor
   deleteButton.setTitle("✕", for: .normal)
   deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 30)

   deleteButton.addTarget(self, action: #selector(didPressDeleteButton), for: .touchUpInside)

   square.addSubview(deleteButton)
   deleteButton.centerYAnchor.constraint(equalTo: square.topAnchor, constant: deltaY).isActive = true
   deleteButton.centerXAnchor.constraint(equalTo: square.centerXAnchor, constant: deltaX).isActive = true
 }

 @objc func didPressDeleteButton() {
   if view.backgroundColor == UIColor.red {
     view.backgroundColor = UIColor.white
   } else {
     view.backgroundColor = UIColor.red
   }
 }

 override func didReceiveMemoryWarning() {
   super.didReceiveMemoryWarning()
 }
 }

 */
