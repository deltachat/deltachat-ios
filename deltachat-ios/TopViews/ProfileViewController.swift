//
//  CameraViewController.swift
//  deltachat-ios
//
//  Created by Friedel Ziegelmayer on 28.12.18.
//  Copyright © 2018 Jonas Reinsch. All rights reserved.
//

import UIKit

class ProfileViewController: UITableViewController {
    var contact: MRContact {
        return MRContact(id: Int(DC_CONTACT_ID_SELF))
    }

    init() {
        super.init(style: .plain)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "My Profile"
    }

    override func viewWillAppear(_: Bool) {
        navigationController?.navigationBar.prefersLargeTitles = false
        tableView.reloadData()
    }

    func displayNewChat(contactId: Int) {
        let chatId = dc_create_chat_by_contact_id(mailboxPointer, UInt32(contactId))
        let chatVC = ChatViewController(chatId: Int(chatId))

        chatVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(chatVC, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 4
        }

        return 0
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = indexPath.row

        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

        let settingsImage = #imageLiteral(resourceName: "baseline_settings_black_18pt").withRenderingMode(.alwaysTemplate)
        cell.imageView?.image = settingsImage
        cell.imageView?.tintColor = UIColor.clear

        if row == 0 {
            cell.textLabel?.text = "Settings"
            cell.imageView?.tintColor = UIColor.gray
        }
        if row == 1 {
            cell.textLabel?.text = "Edit name"
        }

        if row == 2 {
            cell.textLabel?.text = "New chat"
        }

        if row == 3 {
            if let fingerprint = dc_get_securejoin_qr(mailboxPointer, 0) {
                let textView = UITextView()
                textView.text = "Fingerprint: \(fingerprint)"
                textView.heightAnchor.constraint(equalToConstant: 20).isActive = true
                cell.addSubview(textView)

                let frame = CGRect(origin: .zero, size: .init(width: 100, height: 100))
                let imageView = QRCodeView(frame: frame)
                imageView.generateCode(
                    String(cString: fingerprint),
                    foregroundColor: .darkText,
                    backgroundColor: .white
                )

                cell.addSubview(imageView)
                let viewsDictionary = ["textView": textView, "imageView": imageView]
                cell.addConstraints(
                    NSLayoutConstraint.constraints(
                        withVisualFormat: "V:|[textView]-5-[imageView]|", metrics: nil, views: viewsDictionary
                    )
                )
            }
        }

        return cell
    }

    override func tableView(_: UITableView, didSelectRowAt _: IndexPath) {}

    override func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        return 80
    }

    override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 3 {
            return 200
        }

        return 46
    }

    override func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let bg = UIColor(red: 248 / 255, green: 248 / 255, blue: 255 / 255, alpha: 1.0)
        if section == 0 {
            let contactCell = ContactCell()
            contactCell.backgroundColor = bg
            contactCell.nameLabel.text = contact.name
            contactCell.emailLabel.text = contact.email
            contactCell.darkMode = false
            contactCell.selectionStyle = .none
            if let img = contact.profileImage {
                contactCell.setImage(img)
            } else {
                contactCell.setBackupImage(name: contact.name, color: contact.color)
            }
            contactCell.setVerified(isVerified: contact.isVerified)
            return contactCell
        }

        let vw = UIView()
        vw.backgroundColor = bg

        return vw
    }
}
