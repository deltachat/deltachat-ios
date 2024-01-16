//
//  ReactionsOverviewViewController.swift
//  deltachat-ios
//
//  Created by Nathan Mattes on 15.01.24.
//  Copyright © 2024 merlinux GmbH. All rights reserved.
//

import UIKit
import DcCore

class ReactionsOverviewViewController: UIViewController {

    private let tableView: UITableView
    private let reactions: DcReactions
    private let contactIds: [Int]
    private let context: DcContext

    init(reactions: DcReactions, context: DcContext) {

        self.reactions = reactions
        self.contactIds = Array(self.reactions.reactionsByContact.keys)
        self.context = context

        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(ReactionsOverviewTableViewCell.self, forCellReuseIdentifier: ReactionsOverviewTableViewCell.reuseIdentifier)

        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        setupConstraints()

        tableView.dataSource = self

        title = "Reactions"

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(ReactionsOverviewViewController.dismiss(_:)))

    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            view.topAnchor.constraint(equalTo: tableView.topAnchor),
            view.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Actions

    @objc func dismiss(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ReactionsOverviewViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contactIds.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ReactionsOverviewTableViewCell.reuseIdentifier, for: indexPath) as? ReactionsOverviewTableViewCell
        else { fatalError("WTF?! Wrong cell!") }
        
        let contactId = contactIds[indexPath.row]
        let contact = context.getContact(id: contactId)

        if let emojis = reactions.reactionsByContact[contactId] {
            cell.configure(emojis: emojis, contact: contact)
        }

        return cell
    }
}
