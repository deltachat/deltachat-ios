import UIKit
import DcCore

private enum TransportSection: Int {
    case transports = 0
    case add
}

class TransportListViewController: UITableViewController {
    let dcContext: DcContext
    let dcAccounts: DcAccounts

    var transports: [DcEnteredLoginParam]

    let addTransportCell: ActionCell
    private var qrCodeReader: QrCodeReaderController?

    init(dcContext: DcContext, dcAccounts: DcAccounts) {
        self.dcContext = dcContext
        self.dcAccounts = dcAccounts
        self.transports = dcContext.listTransports()

        addTransportCell = ActionCell()
        addTransportCell.actionTitle = String.localized("add_transport")
        addTransportCell.imageView?.image = UIImage(systemName: "plus")

        super.init(style: .insetGrouped)

        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(TransportCell.self, forCellReuseIdentifier: TransportCell.reuseIdentifier)
        hidesBottomBarWhenPushed = true

        title = String.localized("transports")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Actions

    private func editTransport(at indexPath: IndexPath) {
        guard indexPath.row < transports.count else { return }

        let transport = transports[indexPath.row]
        navigationController?.pushViewController(EditTransportViewController(dcAccounts: dcAccounts, editAddr: transport.addr), animated: true)
    }

    private func addTransport() {
        let qrReader = QrCodeReaderController(title: String.localized("add_transport"))
        qrReader.delegate = self
        qrCodeReader = qrReader
        navigationController?.pushViewController(qrReader, animated: true)
    }

    private func deleteTransport(at indexPath: IndexPath) {
        // TODO
    }
}

// MARK: - UITableViewDataSource

extension TransportListViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == TransportSection.transports.rawValue {
            return transports.count
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == TransportSection.transports.rawValue {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: TransportCell.reuseIdentifier, for: indexPath) as? TransportCell else { fatalError() }

            let transport = transports[indexPath.row]
            let isDefault = transport.isDefault(dcContext)

            cell.textLabel?.text = transport.addr
            cell.accessoryType = isDefault ? .checkmark : .none
            cell.detailTextLabel?.text = isDefault ? "Default" : nil

            return cell
        } else {
            return addTransportCell
        }
    }
}

// MARK: - UITableViewDelegate

extension TransportListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == TransportSection.transports.rawValue {
            editTransport(at: indexPath)
        } else {
            addTransport()
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !transports.isEmpty, indexPath.section == TransportSection.transports.rawValue else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            DispatchQueue.main.async {
                self?.deleteTransport(at: indexPath)
                completion(true)
            }
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.accessibilityLabel = String.localized("delete")
        deleteAction.image = Utils.makeImageWithText(image: UIImage(systemName: "trash"), text: String.localized("delete"))

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !transports.isEmpty, indexPath.section == TransportSection.transports.rawValue else { return nil }

        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }
                let children: [UIMenuElement] = [
                    UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", with: indexPath, action: deleteTransport),
                ]
                return UIMenu(children: children)
            }
        )
    }
}

// MARK: - QrCodeReaderDelegate
extension TransportListViewController: QrCodeReaderDelegate {
    func handleQrCode(_ qrCode: String) {
        let parsedQrCode = dcContext.checkQR(qrCode: qrCode)
        if parsedQrCode.state == DC_QR_LOGIN || parsedQrCode.state == DC_QR_ACCOUNT, let host = parsedQrCode.text1 {
            let alert = UIAlertController(title: String.localized("confirm_add_transport"), message: host, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { [weak self] _ in
                guard let self = self else { return }
                self.dismissQRReader()
            }))
            alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                self.dismissQRReader()
                self.addFromQrCode(qrCode)
            }))
            qrCodeReader?.present(alert, animated: true, completion: nil)
        } else {
            qrErrorAlert()
        }
    }

    private func addFromQrCode(_ qrCode: String) {
        // TODO: that should be in bg with progress alert
        // TODO: update list on adding accordingly
        do {
            _ = try self.dcContext.addTransportFromQr(qrCode: qrCode)
        } catch {
            logAndAlert(error: error.localizedDescription)
        }
    }

    private func qrErrorAlert() {
        let alert = UIAlertController(title: String.localized("invalid_transport_qr"), message: dcContext.lastErrorString, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: { [weak self] _ in
            self?.qrCodeReader?.startSession()
        }))
        qrCodeReader?.present(alert, animated: true, completion: nil)
    }

    private func dismissQRReader() {
        self.navigationController?.popViewController(animated: true)
        self.qrCodeReader = nil
    }
}
