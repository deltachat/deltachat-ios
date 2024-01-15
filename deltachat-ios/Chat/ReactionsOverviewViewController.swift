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

    let tableView: UITableView
    let reactions: DcReactions

    init(reactions: DcReactions) {
        
        self.reactions = reactions

        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false

        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        setupConstraints()

        tableView.delegate = self
        tableView.dataSource = self
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
}

// MARK: - UITableViewDelegate

extension ReactionsOverviewViewController: UITableViewDelegate {

}

// MARK: - UITableViewDataSource
extension ReactionsOverviewViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reactions.reactions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
}
