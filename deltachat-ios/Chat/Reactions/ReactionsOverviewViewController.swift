import UIKit
import DcCore

protocol ReactionsOverviewViewControllerDelegate: AnyObject {
    func showContact(_ viewController: UIViewController, with contactId: Int)
}

class ReactionsOverviewViewController: UIViewController {

    private let tableView: UITableView
    private let reactions: DcReactions
    private let contactIds: [Int]
    private let context: DcContext

    weak var delegate: ReactionsOverviewViewControllerDelegate?

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
        tableView.delegate = self

        title = String.localized("reactions")

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(ReactionsOverviewViewController.dismiss(_:)))

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

// MARK: - UITableViewDelegate

extension ReactionsOverviewViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let contactId = contactIds[indexPath.row]

        let isMe = (context.id == contactId)
        if isMe == false {
            delegate?.showContact(self, with: contactId)
        }
    }
}
