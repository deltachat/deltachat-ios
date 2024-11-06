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

class ProxySettingsViewController: UIViewController {

    let dcContext: DcContext
    let dcAccounts: DcAccounts
    
    var proxies: [String]
    var selectedProxy: String?

    let tableView: UITableView
    let addProxyCell: ActionCell
    let toggleProxyCell: SwitchCell

    var addProxyAlert: UIAlertController?

    init(dcContext: DcContext, dcAccounts: DcAccounts) {

        self.dcContext = dcContext
        self.dcAccounts = dcAccounts
        self.proxies = dcContext.getProxies()
        self.selectedProxy = proxies.first

        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseIdentifier)
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ProxyTableViewCell.self, forCellReuseIdentifier: ProxyTableViewCell.reuseIdentifier)

        addProxyCell = ActionCell()
        addProxyCell.actionTitle = String.localized("proxy_add")

        toggleProxyCell = SwitchCell(textLabel: String.localized("proxy_use_proxy"), on: dcContext.isProxyEnabled, action: { cell in
            dcContext.isProxyEnabled = cell.uiSwitch.isOn
        })

        super.init(nibName: nil, bundle: nil)

        title = String.localized("proxy_settings")
        tableView.delegate = self
        tableView.dataSource = self

        view.addSubview(tableView)
        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupConstraints() {
        let constraints = [
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
        ]

        NSLayoutConstraint.activate(constraints)
    }

    private func selectProxy(at indexPath: IndexPath) {
        // TODO: add alert
        let selectedProxyURL = proxies[indexPath.row]
        if dcContext.setConfigFromQR(qrCode: selectedProxyURL) {
            self.selectedProxy = selectedProxyURL
            tableView.reloadData()
            dcAccounts.stopIo()
            dcAccounts.startIo()
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
                self.proxies.insert(proxyURL, at: self.proxies.startIndex)
                self.dcContext.setProxies(proxyURLs: self.proxies)

                DispatchQueue.main.async {
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
        // TODO: Delete Proxy, if proxy was selected: Deselect proxy
    }
}

// MARK: - UITableViewDataSource

extension ProxySettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if proxies.isEmpty {
            return 2
        } else {
            return 3
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if proxies.isEmpty {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                return toggleProxyCell
            } else /* if indexPath.section == ProxySettingsSection.add.rawValue */ {
                return addProxyCell
            }
        } else {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
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
                // ProxyCell with proxies[indexPath.row]
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                return addProxyCell
            }
        }
    }
}

// MARK: - UITableViewDelegate

extension ProxySettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if proxies.isEmpty {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                toggleProxyCell.uiSwitch.isOn.toggle()
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
}
