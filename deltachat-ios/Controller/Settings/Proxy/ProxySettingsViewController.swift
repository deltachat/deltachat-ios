import UIKit
import DcCore

private enum ProxySettingsSection: Int {
    case enableProxies = 0
    case proxies
    case add

    var title: String? {
        switch self {
        case .enableProxies:
            return nil
        case .proxies:
            return String.localized("proxy_list_header")
        case .add:
            return nil
        }
    }
}

class ProxySettingsViewController: UITableViewController {

    let dcContext: DcContext
    let dcAccounts: DcAccounts
    
    var proxies: [String]
    var selectedProxy: String?

    let addProxyCell: ActionCell
    let toggleProxyCell: SwitchCell

    var addProxyAlert: UIAlertController?

    init(dcContext: DcContext, dcAccounts: DcAccounts) {

        self.dcContext = dcContext
        self.dcAccounts = dcAccounts
        self.proxies = dcContext.getProxies()
        self.selectedProxy = proxies.first

        addProxyCell = ActionCell()
        addProxyCell.actionTitle = String.localized("proxy_add")
        addProxyCell.imageView?.image = UIImage(systemName: "plus")
        toggleProxyCell = SwitchCell(textLabel: String.localized("proxy_use_proxy"), on: dcContext.isProxyEnabled)

        super.init(style: .insetGrouped)

        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseIdentifier)
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ProxyTableViewCell.self, forCellReuseIdentifier: ProxyTableViewCell.reuseIdentifier)
        hidesBottomBarWhenPushed = true

        toggleProxyCell.uiSwitch.isEnabled = (proxies.isEmpty == false)
        toggleProxyCell.action = { [weak self] cell in
            guard let self, self.proxies.isEmpty == false else { return }

            self.dcContext.isProxyEnabled = cell.uiSwitch.isOn
            self.dcAccounts.restartIO()
        }

        title = String.localized("proxy_settings")

        NotificationCenter.default.addObserver(self, selector: #selector(ProxySettingsViewController.handleConnectivityChanged(_:)), name: Event.connectivityChanged, object: nil)

    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let proxies = dcContext.getProxies()
        self.proxies = proxies
        self.selectedProxy = proxies.first
    }

    // MARK: - Actions

    private func selectProxy(at indexPath: IndexPath) {
        let selectedProxyURL = proxies[indexPath.row]
        if dcContext.setConfigFromQR(qrCode: selectedProxyURL) {
            selectedProxy = selectedProxyURL
            tableView.reloadData()
            dcAccounts.restartIO()
        }
    }

    private func addProxy() {
        let alertController = UIAlertController(
            title: String.localized("proxy_add"),
            message: String.localized("proxy_add_explain"),
            preferredStyle: .alert
        )

        let addProxyAction = UIAlertAction(title: String.localized("proxy_use_proxy"), style: .default) { [weak self] _ in
            guard let self,
                  let proxyUrlTextfield = self.addProxyAlert?.textFields?.first,
                  let proxyURL = proxyUrlTextfield.text else { return }

            let parsedProxy = self.dcContext.checkQR(qrCode: proxyURL)
            if parsedProxy.state == DC_QR_PROXY, self.dcContext.setConfigFromQR(qrCode: proxyURL) {
                self.dcAccounts.restartIO()
                self.proxies = dcContext.getProxies()
                self.selectedProxy = proxies.first

                DispatchQueue.main.async {
                    self.toggleProxyCell.uiSwitch.isEnabled = (self.proxies.isEmpty == false)
                    self.tableView.reloadData()
                }
            } else {
                let errorAlert = UIAlertController(title: String.localized("error"), message: String.localized("proxy_invalid"), preferredStyle: .alert)

                let okAction = UIAlertAction(title: String.localized("ok"), style: .default)
                errorAlert.addAction(okAction)

                self.present(errorAlert, animated: true)
            }
        }

        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel)
        alertController.addAction(addProxyAction)
        alertController.addAction(cancelAction)
        alertController.addTextField { textfield in
            textfield.placeholder = String.localized("proxy_add_url_hint")
        }

        present(alertController, animated: true)
        self.addProxyAlert = alertController
    }

    private func deleteProxy(at indexPath: IndexPath) {
        let proxyToRemove = proxies[indexPath.row]
        let host = dcContext.checkQR(qrCode: proxyToRemove).text1 ?? ""

        let deleteAlert = UIAlertController(title: String.localized("proxy_delete"), message: String.localized(stringID: "proxy_delete_explain", parameter: host), preferredStyle: .safeActionSheet)

        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel)
        let deleteAction = UIAlertAction(title: String.localized("proxy_delete"), style: .destructive) { [weak self] _ in
            guard let self else { return }

            if let selectedProxy = self.selectedProxy, proxyToRemove == selectedProxy {
                self.dcContext.isProxyEnabled = false
            }

            self.proxies.remove(at: indexPath.row)
            self.dcContext.setProxies(proxyURLs: proxies)
            self.dcAccounts.restartIO()
            DispatchQueue.main.async {
                self.toggleProxyCell.uiSwitch.isEnabled = (self.proxies.isEmpty == false)
                self.tableView.reloadData()
            }
        }

        deleteAlert.addAction(cancelAction)
        deleteAlert.addAction(deleteAction)
        present(deleteAlert, animated: true)
    }

    private func shareProxy(at indexPath: IndexPath) {
        let proxyToShare = proxies[indexPath.row]
        let shareProxyViewController = ShareProxyViewController(dcContext: dcContext, proxyUrlString: proxyToShare)

        let navigationController = UINavigationController(rootViewController: shareProxyViewController)
        if #available(iOS 15.0, *), let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]

            present(navigationController, animated: true)
        } else {
            show(navigationController, sender: self)
        }
    }

    // MARK: - Notifications

    @objc private func handleConnectivityChanged(_ notification: Notification) {
        guard dcContext.id == notification.userInfo?["account_id"] as? Int else { return }

        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
}

// MARK: - UITableViewDataSource

extension ProxySettingsViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        if proxies.isEmpty {
            return 2
        } else {
            return 3
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if proxies.isEmpty {
            if section == ProxySettingsSection.enableProxies.rawValue {
                return 1
            } else /* if section == ProxySettingsSection.add.rawValue */ {
                return 1
            }
        } else {
            if section == ProxySettingsSection.enableProxies.rawValue {
                return 1
            } else if section == ProxySettingsSection.proxies.rawValue {
                return proxies.count
            } else /*if section == ProxySettingsSection.add.rawValue*/ {
                return 1
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if proxies.isEmpty {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                toggleProxyCell.uiSwitch.isOn = dcContext.isProxyEnabled
                return toggleProxyCell
            } else /* if indexPath.section == ProxySettingsSection.add.rawValue */ {
                return addProxyCell
            }
        } else {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                toggleProxyCell.uiSwitch.isOn = dcContext.isProxyEnabled
                return toggleProxyCell
            } else if indexPath.section == ProxySettingsSection.proxies.rawValue {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: ProxyTableViewCell.reuseIdentifier, for: indexPath) as? ProxyTableViewCell else { fatalError() }

                let proxyUrl = proxies[indexPath.row]

                let connectionStateText: String?

                if let selectedProxy, selectedProxy == proxyUrl {
                    cell.accessoryType = .checkmark
                    if dcContext.isProxyEnabled {
                        connectionStateText = DcUtils.getConnectivityString(dcContext: dcContext, connectedString: String.localized("connectivity_connected"))
                    } else {
                        connectionStateText = String.localized("connectivity_not_connected")
                    }
                } else {
                    cell.accessoryType = .none
                    connectionStateText = nil
                }

                cell.configure(with: proxyUrl, dcContext: dcContext, connectionStateText: connectionStateText)

                return cell
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                return addProxyCell
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard proxies.isEmpty == false else { return nil }

        if section == ProxySettingsSection.proxies.rawValue {
            return ProxySettingsSection.proxies.title
        } else {
            return nil
        }

    }
}

// MARK: - UITableViewDelegate

extension ProxySettingsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if proxies.isEmpty {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                // do nothing as there are no proxies that could be used
            } else /* if indexPath.section == ProxySettingsSection.add.rawValue */ {
                addProxy()
            }
        } else {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                // enabling/disabling requires using the switch, as usual internally and also by the system and most other apps
            } else if indexPath.section == ProxySettingsSection.proxies.rawValue {
                selectProxy(at: indexPath)
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                addProxy()
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard
            proxies.isEmpty == false,
            indexPath.section == ProxySettingsSection.proxies.rawValue
        else { return nil }

        let shareAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            DispatchQueue.main.async {
                self?.shareProxy(at: indexPath)
                completion(true)
            }
        }
        shareAction.backgroundColor = .systemGreen
        shareAction.image = Utils.makeImageWithText(image: UIImage(systemName: "square.and.arrow.up"), text: String.localized("menu_share"))

        let configuration = UISwipeActionsConfiguration(actions: [shareAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration

    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard
            proxies.isEmpty == false,
            indexPath.section == ProxySettingsSection.proxies.rawValue
        else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
            DispatchQueue.main.async {
                self?.deleteProxy(at: indexPath)
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
        guard
            proxies.isEmpty == false,
            indexPath.section == ProxySettingsSection.proxies.rawValue
        else { return nil }

        return UIContextMenuConfiguration(
            identifier: nil,
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }
                let children: [UIMenuElement] = [
                    UIAction.menuAction(localizationKey: "menu_share", systemImageName: "square.and.arrow.up", with: indexPath, action: shareProxy),
                    UIAction.menuAction(localizationKey: "delete", attributes: [.destructive], systemImageName: "trash", with: indexPath, action: deleteProxy),
                ]
                return UIMenu(children: children)
            }
        )
    }
}
