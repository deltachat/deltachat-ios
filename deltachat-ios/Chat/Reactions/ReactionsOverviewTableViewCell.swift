//
//  ReactionsOverviewTableViewCell.swift
//  deltachat-ios
//
//  Created by Nathan Mattes on 16.01.24.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import UIKit
import DcCore

class ReactionsOverviewTableViewCell: UITableViewCell {
    static let reuseIdentifier = "ReactionsOverviewTableViewCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(emojis: [String], contact: DcContact) {
        let string = "\(contact.displayName) reacted with \(emojis.joined(separator: ","))"

        textLabel?.text = string
    }
}
