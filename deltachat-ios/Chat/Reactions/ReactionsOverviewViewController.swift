import UIKit
import DcCore

protocol ReactionsOverviewViewControllerDelegate: AnyObject {
    func showContact(_ viewController: UIViewController, with contactId: Int)
}

class ReactionsOverviewViewController: UIViewController {

    private let tableView: UITableView
    private let showFrequencies: Bool
    private let texts: [String]
    private let contactIds: [Int]

    weak var delegate: ReactionsOverviewViewControllerDelegate?

    init(reactions: DcReactions, showFrequencies: Bool, context: DcContext) {

        self.showFrequencies = showFrequencies

        // layout by strings is not great, but good enough for now for a secondary UI
        if showFrequencies {
            self.contactIds = []
            self.texts = reactions.reactions.map { reaction in
                return "\(reaction.emoji)   " + String.localized(stringID: "n_reactions", parameter: reaction.count)
            }
        } else {
            self.contactIds = Array(reactions.reactionsByContact.keys)
            self.texts = self.contactIds.map { contactId in
                let contact = context.getContact(id: contactId)
                if let emojis = reactions.reactionsByContact[contactId] {
                    return "\(contact.displayName): \(emojis.joined(separator: ","))"
                }
                return ""
            }
        }

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
        return texts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ReactionsOverviewTableViewCell.reuseIdentifier, for: indexPath) as? ReactionsOverviewTableViewCell
        else { fatalError("WTF?! Wrong cell!") }

        cell.textLabel?.text = texts[indexPath.row]
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ReactionsOverviewViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if !showFrequencies {
            let contactId = contactIds[indexPath.row]
            if contactId != DC_CONTACT_ID_SELF {
                delegate?.showContact(self, with: contactId)
            }
        }
    }
}
