import UIKit
import DcCore

protocol SendContactViewControllerDelegate: AnyObject {
    func contactSelected(_ viewController: SendContactViewController, contactId: Int)
}

class SendContactViewController: UIViewController {

    private let context: DcContext
    private let contactIds: [Int]

    let tableView: UITableView

    var delegate: SendContactViewControllerDelegate?

    init(dcContext: DcContext) {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseIdentifier)

        context = dcContext
        contactIds = dcContext.getContacts(flags: DC_GCL_ADD_SELF)

        super.init(nibName: nil, bundle: nil)

        tableView.dataSource = self
        tableView.delegate = self
        title = String.localized("contacts_title")

        view.addSubview(tableView)
        setupConstraints()

        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(SendContactViewController.cancel(_:)))
        navigationItem.rightBarButtonItem = cancelButton
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Actions

    @objc func cancel(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension SendContactViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let contactId = contactIds[indexPath.row]
        delegate?.contactSelected(self, contactId: contactId)

        dismiss(animated: true)
    }
}

extension SendContactViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contactIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseIdentifier, for: indexPath) as? ContactCell else { fatalError("Where's my ContactCell??") }

        let contactId = contactIds[indexPath.row]
        let viewModel = ContactCellViewModel.make(contactId: contactId, dcContext: context)
        cell.updateCell(cellViewModel: viewModel)

        return cell
    }
}