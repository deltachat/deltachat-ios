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
    private var progressAlertHandler: ProgressAlertHandler?

    init(dcContext: DcContext, dcAccounts: DcAccounts, continueQrScan: String? = nil) {
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

        if let continueQrScan {
            DispatchQueue.main.async { [weak self] in
                self?.addFromQrCode(continueQrScan)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func reloadTransports() {
        transports = dcContext.listTransports()
        tableView.reloadData()
    }

    // MARK: - Actions

    private func setDefaultTransport(at indexPath: IndexPath) {
        guard let transport = transports.get(at: indexPath.row) else { return }
        dcContext.setConfig("configured_addr", transport.addr)
        tableView.reloadData()
    }

    private func editTransport(at indexPath: IndexPath) {
        guard let transport = transports.get(at: indexPath.row) else { return }
        navigationController?.pushViewController(EditTransportViewController(dcAccounts: dcAccounts, editAddr: transport.addr), animated: true)
    }

    private func addTransport() {
        let qrReader = QrCodeReaderController(title: String.localized("add_transport"))
        qrReader.delegate = self
        qrCodeReader = qrReader
        navigationController?.pushViewController(qrReader, animated: true)
    }

    private func deleteTransport(at indexPath: IndexPath) {
        guard let transport = transports.get(at: indexPath.row) else { return }

        let parts = transport.addr.components(separatedBy: "@")
        let text = String.localized(stringID: "confirm_remove_transport", parameter: parts.last ?? transport.addr)
        let alert = UIAlertController(title: text, message: nil, preferredStyle: .safeActionSheet)
        alert.addAction(UIAlertAction(title: String.localized("remove_transport"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            do {
                _ = try self.dcContext.deleteTransport(addr: transport.addr)
            } catch {
                logAndAlert(error: error.localizedDescription)
            }
            reloadTransports()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
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
            let parts = transport.addr.components(separatedBy: "@")

            cell.textLabel?.text = parts.last ?? transport.addr
            cell.detailTextLabel?.text = (parts.first ?? "") + (isDefault ? (" · " + String.localized("def")) : "")
            cell.accessoryType = isDefault ? .checkmark : .none

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
            setDefaultTransport(at: indexPath)
        } else {
            addTransport()
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == TransportSection.transports.rawValue else { return nil }
        guard let transport = transports.get(at: indexPath.row) else { return nil }
        var actions: [UIContextualAction] = []

        if !transport.isDefault(dcContext) {
            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
                DispatchQueue.main.async {
                    self?.deleteTransport(at: indexPath)
                    completion(true)
                }
            }
            deleteAction.backgroundColor = .systemRed
            deleteAction.accessibilityLabel = String.localized("delete")
            deleteAction.image = Utils.makeImageWithText(image: UIImage(systemName: "trash"), text: String.localized("delete"))
            actions.append(deleteAction)
        }

        let editAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            DispatchQueue.main.async {
                self?.editTransport(at: indexPath)
                completion(true)
            }
        }
        editAction.backgroundColor = .lightGray
        editAction.accessibilityLabel = String.localized("edit_transport")
        editAction.image = Utils.makeImageWithText(image: UIImage(systemName: "pencil"), text: String.localized("global_menu_edit_desktop"))
        actions.append(editAction)

        let actionsConfiguration = UISwipeActionsConfiguration(actions: actions)
        actionsConfiguration.performsFirstActionWithFullSwipe = !transport.isDefault(dcContext)
        return actionsConfiguration
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == TransportSection.transports.rawValue else { return nil }

        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }
                guard let transport = transports.get(at: indexPath.row) else { return nil }
                var children: [UIMenuElement] = []

                children.append(UIAction.menuAction(localizationKey: "edit_transport", systemImageName: "pencil", with: indexPath, action: editTransport))
                if !transport.isDefault(dcContext) {
                    children.append(UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", with: indexPath, action: deleteTransport))
                }

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
        let progressAlertHandler = ProgressAlertHandler(notification: Event.configurationProgress, onSuccess: { [weak self] in
            self?.reloadTransports()
        })
        progressAlertHandler.dataSource = self
        progressAlertHandler.showProgressAlert(title: String.localized("add_transport"), dcContext: self.dcContext)

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }

            do {
                _ = try self.dcContext.addTransportFromQr(qrCode: qrCode)
            } catch {
                DispatchQueue.main.async {
                    progressAlertHandler.updateProgressAlert(error: error.localizedDescription)
                }
            }
        }

        self.progressAlertHandler = progressAlertHandler
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
