import UIKit
import DcCore

enum ProxySettingsSection: Int {
    case enableProxies = 0
    case proxies
    case add

    var title: String? {
        switch self {
        case .enableProxies:
            return nil
        case .proxies:
            return "Proxies"
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
        toggleProxyCell = SwitchCell(textLabel: String.localized("proxy_use_proxy"), on: dcContext.isProxyEnabled)

        super.init(style: .grouped)

        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseIdentifier)
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ProxyTableViewCell.self, forCellReuseIdentifier: ProxyTableViewCell.reuseIdentifier)

        toggleProxyCell.uiSwitch.isEnabled = (proxies.isEmpty == false)
        toggleProxyCell.action = { [weak self] cell in
            guard let self, self.proxies.isEmpty == false else { return }

            dcContext.isProxyEnabled = cell.uiSwitch.isOn
        }

        title = String.localized("proxy_settings")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func selectProxy(at indexPath: IndexPath) {
        let selectedProxyURL = proxies[indexPath.row]

        let selectAlert = UIAlertController(
            title: String.localized("proxy_use_proxy"),
            message: String.localized(stringID: "proxy_use_proxy_confirm", parameter: selectedProxyURL),
            preferredStyle: .alert
        )

        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel)
        let selectAction = UIAlertAction(title: String.localized("proxy_use_proxy"), style: .default) { [weak self] _ in

            guard let self else { return }
            if self.dcContext.setConfigFromQR(qrCode: selectedProxyURL) {
                self.selectedProxy = selectedProxyURL
                self.tableView.reloadData()
                self.dcAccounts.restartIO()
            }
        }
        selectAlert.addAction(cancelAction)
        selectAlert.addAction(selectAction)

        present(selectAlert, animated: true)
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
                self.proxies.insert(proxyURL, at: self.proxies.startIndex)
                self.dcContext.setProxies(proxyURLs: self.proxies)

                DispatchQueue.main.async {
                    self.toggleProxyCell.uiSwitch.isEnabled = (self.proxies.isEmpty == false)
                    self.tableView.reloadData()
                }
            } else {
                // show another alert with "proxy_invalid"
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

        let deleteAlert = UIAlertController(title: String.localized("proxy_delete"), message: String.localized(stringID: "proxy_delete_explain", parameter: proxyToRemove), preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: String.localized("cancel"), style: .cancel)
        let deleteAction = UIAlertAction(title: String.localized("proxy_delete"), style: .destructive) { [weak self] _ in
            guard let self else { return }

            if let selectedProxy = self.selectedProxy, proxyToRemove == selectedProxy {
                self.dcContext.isProxyEnabled = false
            }

            self.proxies.remove(at: indexPath.row)
            self.dcContext.setProxies(proxyURLs: proxies)
            DispatchQueue.main.async {
                self.toggleProxyCell.uiSwitch.isEnabled = (self.proxies.isEmpty == false)
                self.tableView.reloadData()
            }
        }

        deleteAlert.addAction(cancelAction)
        deleteAlert.addAction(deleteAction)
        present(deleteAlert, animated: true)
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

                let proxy = proxies[indexPath.row]
                cell.textLabel?.text = proxy

                if let selectedProxy, selectedProxy == proxy {
                    cell.accessoryType = .checkmark
                } else {
                    cell.accessoryType = .none
                }

                return cell
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                return addProxyCell
            }
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
                toggleProxyCell.uiSwitch.isOn.toggle()
            } else if indexPath.section == ProxySettingsSection.proxies.rawValue {
                selectProxy(at: indexPath)
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                addProxy()
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard
            proxies.isEmpty == false,
            indexPath.section == ProxySettingsSection.proxies.rawValue
        else { return nil }

        let deleteAction = UIContextualAction(style: .destructive, title: String.localized("proxy_delete")) { [weak self] _, _, completion in
            DispatchQueue.main.async {
                self?.deleteProxy(at: indexPath)
                completion(true)
            }
        }
        deleteAction.backgroundColor = .red

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }
}