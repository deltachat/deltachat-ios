import UIKit

class ProfileCell: UITableViewCell {

    private let detailView = ContactDetailHeader()

    init(contact: DcContact) {
        super.init(style: .default, reuseIdentifier: nil)
        accessoryType = .disclosureIndicator
        setupSubviews()
        update(contact: contact)
        detailView.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        contentView.addSubview(detailView)
        detailView.translatesAutoresizingMaskIntoConstraints = false
        detailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0).isActive = true
        detailView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0).isActive = true
        detailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0).isActive = true
        detailView.trailingAnchor.constraint(equalTo: accessoryView?.trailingAnchor ?? contentView.trailingAnchor, constant: 0).isActive = true
        detailView.heightAnchor.constraint(equalToConstant: ContactDetailHeader.headerHeight).isActive = true
    }

    func update(contact: DcContact) {
        let displayName = DcConfig.displayname
        let email = DcConfig.addr ?? contact.email
        detailView.updateDetails(title: displayName ?? contact.displayName, subtitle: email)
        if let image = contact.profileImage {
            detailView.setImage(image)
        } else {
            detailView.setBackupImage(name: displayName ?? email, color: contact.color)
        }
    }
}
