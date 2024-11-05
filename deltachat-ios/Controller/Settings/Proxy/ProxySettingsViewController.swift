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
    let proxies: [String]
    var selectedProxy: String?

    let tableView: UITableView
    let addProxyCell: ActionCell
    let toggleProxyCell: SwitchCell

    init(dcContext: DcContext) {

        self.dcContext = dcContext
        self.proxies = dcContext.getProxies()


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
        // TODO: set selected proxy
    }

    private func addProxy() {
        // TODO: Show alert with Textfield (alternative: Dedicated Controller?) to add a new proxy-URL, reloadList afterwards
    }

    private func deleteProxy(at indexPath: IndexPath) {
        // TODO: Delete Proxy, if proxy was selected: Deselect proxy
    }
}

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
                // ProxyCell with proxies[indexPath.row]
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                return addProxyCell
            }
        }
        return UITableViewCell()
    }
}

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
                // select proxy
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                addProxy()
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
