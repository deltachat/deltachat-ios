import UIKit
import DcCore

enum ProxySettingsSection: Int {
    case enableProxies = 1
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

enum ProxySettingsItem {
    case enable
    case entry(DcLot) // dcContext.checkQr(proxyUrl); DcLot? URL?
    case add
}

class ProxySettingsViewController: UIViewController {

    let dcContext: DcContext
    let tableView: UITableView
    let proxies: [String]

    init(dcContext: DcContext) {

        self.dcContext = dcContext
        self.proxies = dcContext.getProxies()
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseIdentifier)
        tableView.register(ActionCell.self, forCellReuseIdentifier: ActionCell.reuseIdentifier)
        tableView.register(ProxyTableViewCell.self, forCellReuseIdentifier: ProxyTableViewCell.reuseIdentifier)

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

    private func enableProxies() {
        // TODO: Enable Proxies in general
    }

    private func disableProxies() {
        // TODO: Enable Proxies in general
    }
}

extension ProxySettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if proxies.isEmpty == false {
            return 3
        } else {
            return 2
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if proxies.isEmpty == false {
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
        if proxies.isEmpty == false {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                // SwitchCell with enable/disable
            } else /* if indexPath.section == ProxySettingsSection.add.rawValue */ {
                // ActionCell with add
            }
        } else {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                // SwitchCell with enable/disable
            } else if indexPath.section == ProxySettingsSection.proxies.rawValue {
                // ProxyCell with proxies[indexPath.row]
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                // ActionCell with add
            }
        }
        return UITableViewCell()
    }
}

extension ProxySettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if proxies.isEmpty == false {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                // enable/disable proxy and toggle switch
            } else /* if indexPath.section == ProxySettingsSection.add.rawValue */ {
                // open dialog to add a new proxy
            }
        } else {
            if indexPath.section == ProxySettingsSection.enableProxies.rawValue {
                // enable/disable proxy and toggle switch
            } else if indexPath.section == ProxySettingsSection.proxies.rawValue {
                // select proxy
            } else /*if indexPath.section == ProxySettingsSection.add.rawValue*/ {
                // open dialog to add a new proxy
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
