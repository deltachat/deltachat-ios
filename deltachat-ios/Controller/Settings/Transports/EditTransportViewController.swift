import SafariServices
import UIKit
import DcCore

class EditTransportViewController: UITableViewController {
    private var dcContext: DcContext
    private let dcAccounts: DcAccounts
    var onLoginSuccess: (() -> Void)?
    var progressAlertHandler: ProgressAlertHandler?

    private let tagAdvancedCell = 2
    private let tagImapSecurityCell = 6
    private let tagSmtpSecurityCell = 11
    private let tagCertCheckCell = 12
    private let tagViewLogCell = 15
    private let tagProxyCell = 16

    private let tagTextFieldEmail = 100
    private let tagTextFieldPassword = 200
    private let tagTextFieldImapLogin = 300
    private let tagTextFieldImapServer = 400
    private let tagTextFieldImapPort = 500
    private let tagTextFieldSmtpLogin = 600
    private let tagTextFieldSmtpPassword = 700
    private let tagTextFieldSmtpServer = 800
    private let tagTextFieldSmtpPort = 900

    // add cells to sections

    let basicSection = 100
    let advancedSection = 200
    private var sections = [Int]()

    private lazy var basicSectionCells: [UITableViewCell] = [emailCell, passwordCell]
    private lazy var advancedSectionCells: [UITableViewCell] = [
        advancedShowCell,
        imapSecurityCell,
        imapUserCell,
        imapServerCell,
        imapPortCell,
        smtpSecurityCell,
        smtpUserCell,
        smtpPasswordCell,
        smtpServerCell,
        smtpPortCell,
        certCheckCell,
        proxyCell,
        viewLogCell
    ]
    private let editAddr: String?
    private var advancedSectionShowing: Bool = false
    private var providerInfoShowing: Bool = false

    private var provider: DcProvider?

    // MARK: - cells

    private lazy var emailCell: TextFieldCell = {
        let cell = TextFieldCell.makeEmailCell(delegate: self)
        cell.textField.addTarget(self, action: #selector(emailCellEdited), for: .editingChanged)
        cell.textField.tag = tagTextFieldEmail
        cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        cell.textField.returnKeyType = .next
        if editAddr != nil {
            cell.textField.isUserInteractionEnabled = false
        }
        return cell
    }()

    private lazy var passwordCell: TextFieldCell = {
        let cell = TextFieldCell.makePasswordCell(delegate: self)
        cell.textField.tag = tagTextFieldPassword
        cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        cell.textField.returnKeyType = advancedSectionShowing ? .next : .default
        return cell
    }()

    private lazy var providerInfoCell: ProviderInfoCell = {
        let cell = ProviderInfoCell()
        cell.onInfoButtonPressed = { [weak self] in
            self?.handleProviderInfoButton()
        }
        return cell
    }()

    lazy var advancedShowCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("menu_more_options")
        cell.accessoryType = .disclosureIndicator
        cell.tag = tagAdvancedCell
        return cell
    }()

    lazy var imapServerCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_imap_server",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.textField.tag = tagTextFieldImapServer
        cell.textField.autocorrectionType = .no
        cell.textField.spellCheckingType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.returnKeyType = .next
        return cell
    }()

    lazy var imapUserCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_imap_login",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.textField.tag = tagTextFieldImapLogin
        cell.textField.autocorrectionType = .no
        cell.textField.spellCheckingType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.returnKeyType = .next
        return cell
    }()

    func editablePort(port: Int?) -> String {
        if let port = port {
            if port == 0 {
                return ""
            }
            return "\(port)"
        } else {
            return ""
        }
    }

    lazy var imapPortCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_imap_port",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.textField.tag = tagTextFieldImapPort
        cell.textField.keyboardType = .numberPad
        return cell
    }()

    let imapSecurityValue = AccountSetupSecurityValue()
    lazy var imapSecurityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_imap_security")
        cell.accessoryType = .disclosureIndicator
        cell.tag = tagImapSecurityCell
        return cell
    }()

    lazy var smtpServerCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_smtp_server",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.textField.tag = tagTextFieldSmtpServer
        cell.textField.autocorrectionType = .no
        cell.textField.spellCheckingType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.returnKeyType = .next
        return cell
    }()

    lazy var smtpUserCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_smtp_login",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.textField.tag = tagTextFieldSmtpLogin
        cell.textField.autocorrectionType = .no
        cell.textField.spellCheckingType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.returnKeyType = .next
        return cell
    }()

    lazy var smtpPortCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_smtp_port",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.textField.tag = tagTextFieldSmtpPort
        cell.textField.keyboardType = .numberPad
        return cell
    }()

    lazy var smtpPasswordCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_smtp_password",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.textField.textContentType = UITextContentType.password
        cell.textField.isSecureTextEntry = true
        cell.textField.tag = tagTextFieldSmtpPassword
        cell.textField.returnKeyType = .next
        return cell
    }()

    let smtpSecurityValue = AccountSetupSecurityValue()
    lazy var smtpSecurityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_smtp_security")
        cell.tag = tagSmtpSecurityCell
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    var certValue: String = "automatic"
    lazy var certCheckCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_certificate_checks")
        cell.tag = tagCertCheckCell
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    lazy var proxyCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("proxy_settings")
        cell.tag = tagProxyCell
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    lazy var viewLogCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("pref_view_log")
        cell.tag = tagViewLogCell
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    private var cancelButton: UIBarButtonItem {
        let button =  UIBarButtonItem(title: String.localized("cancel"), style: .plain, target: self, action: #selector(cancelButtonPressed))
        return button
    }

    private lazy var loginButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("login_title"), style: .done, target: self, action: #selector(loginButtonPressed))
        button.isEnabled = !dcContext.isConfigured()
        return button
    }()

    // MARK: - constructor
    init(dcAccounts: DcAccounts, editAddr: String? = nil) {
        self.editAddr = editAddr
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()

        self.sections.append(basicSection)
        self.sections.append(advancedSection)

        super.init(style: .insetGrouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if editAddr != nil {
            title = String.localized("edit_transport")
        } else {
            title = String.localized("manual_account_setup_option")
        }
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = loginButton

        var loginParam: DcEnteredLoginParam?
        let transports = dcContext.listTransports()
        for t in transports {
            if t.addr == self.editAddr {
                loginParam = t
            }
        }

        // init text cells (selections are initialized at viewWillAppear)
        emailCell.setText(text: loginParam?.addr)
        passwordCell.setText(text: loginParam?.password)
        imapUserCell.setText(text: loginParam?.imapUser)
        imapServerCell.setText(text: loginParam?.imapServer)
        imapPortCell.setText(text: editablePort(port: loginParam?.imapPort))
        imapSecurityValue.value = loginParam?.imapSecurity ?? "automatic"
        smtpUserCell.setText(text: loginParam?.smtpUser)
        smtpPasswordCell.setText(text: loginParam?.smtpPassword)
        smtpServerCell.setText(text: loginParam?.smtpServer)
        smtpPortCell.setText(text: editablePort(port: loginParam?.smtpPort))
        smtpSecurityValue.value = loginParam?.smtpSecurity ?? "automatic"
        certValue = loginParam?.certificateChecks ?? "automatic"

        handleLoginButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // init selection cells (updated them when coming back from a child view controller)
        imapSecurityCell.detailTextLabel?.text = SecuritySettingsViewController.valueToName(value: imapSecurityValue.value)
        smtpSecurityCell.detailTextLabel?.text = SecuritySettingsViewController.valueToName(value: smtpSecurityValue.value)
        certCheckCell.detailTextLabel?.text = CertificateCheckViewController.valueToName(value: certValue)
        proxyCell.detailTextLabel?.text = dcContext.isProxyEnabled ? String.localized("on") : nil
    }

    override func viewWillDisappear(_ animated: Bool) {
        resignFirstResponderOnAllCells()
    }

    // MARK: - Table view data source
    override func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sections[section] == basicSection {
            return basicSectionCells.count
        } else {
            return advancedSectionShowing ? advancedSectionCells.count : 1
        }
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if sections[section] == basicSection {
            return String.localized("login_advanced_hint")
        } else {
            return nil
        }
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if sections[section] == basicSection {
            return basicSectionCells[row]
        } else {
            return advancedSectionCells[row]
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let tappedCell = tableView.cellForRow(at: indexPath) else { return }
        switch tappedCell.tag {
        case tagAdvancedCell:
            toggleAdvancedSection()
        case tagImapSecurityCell:
            showImapSecurityOptions()
        case tagSmtpSecurityCell:
            showSmtpSecurityOptions()
        case tagCertCheckCell:
            showCertCheckOptions()
        case tagViewLogCell:
            tableView.deselectRow(at: indexPath, animated: false)
            showLogViewController()
        case tagProxyCell:
            showProxySettings()
        default:
            break
        }
    }

    // MARK: - actions
    private func toggleAdvancedSection() {
        let willShow = !advancedSectionShowing

        guard let advancedSectionIndex = sections.firstIndex(of: advancedSection) else { return }
        var advancedIndexPaths: [IndexPath] = advancedSectionCells.indices.map { IndexPath(row: $0, section: advancedSectionIndex) }
        advancedIndexPaths.removeFirst() // do not touch the first item that is the switch itself

        // on expansion, replace the disclosureIndicator by an n-dash
        advancedShowCell.accessoryType = willShow ? .none : .disclosureIndicator
        advancedShowCell.detailTextLabel?.text = willShow ? "\u{2013}" : nil

        advancedSectionShowing = willShow // set flag before delete/insert, because cellForRowAt will be triggered and uses this flag
        passwordCell.textField.returnKeyType = willShow ? .next : .default
        if willShow {
            tableView.insertRows(at: advancedIndexPaths, with: .fade)
        } else {
            tableView.deleteRows(at: advancedIndexPaths, with: .fade)
        }
        tableView.reloadData()
    }

    @objc private func cancelButtonPressed() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func loginButtonPressed() {
        guard let emailAddress = emailCell.getText() else { return }
        login(emailAddress: emailAddress)
    }

    private func updateProviderInfo() {
        provider = dcContext.getProviderFromEmailWithDns(addr: emailCell.getText() ?? "")
        if let hint = provider?.beforeLoginHint,
            let status = provider?.status,
            let statusType = ProviderInfoStatus(rawValue: status),
            !hint.isEmpty {
            providerInfoCell.updateInfo(hint: hint, hintType: statusType)
            if !providerInfoShowing {
                showProviderInfo()
            }
        } else if providerInfoShowing {
            hideProviderInfo()
        }
    }

    private func showProviderInfo() {
        basicSectionCells = [emailCell, passwordCell, providerInfoCell]
        let providerInfoCellIndexPath = IndexPath(row: 2, section: 0)
        tableView.insertRows(at: [providerInfoCellIndexPath], with: .fade)
        providerInfoShowing = true
    }

    private func hideProviderInfo() {
        providerInfoCell.updateInfo(hint: nil, hintType: .none)
        basicSectionCells = [emailCell, passwordCell]
        let providerInfoCellIndexPath = IndexPath(row: 2, section: 0)
        tableView.deleteRows(at: [providerInfoCellIndexPath], with: .automatic)
        providerInfoShowing = false
    }

    private func login(emailAddress: String) {
        let progressAlertHandler = ProgressAlertHandler(notification: Event.configurationProgress, checkForInternetConnectivity: true) { [weak self] in
            self?.handleLoginSuccess()
        }
        progressAlertHandler.dataSource = self
        resignFirstResponderOnAllCells()
        progressAlertHandler.showProgressAlert(title: nil, dcContext: dcContext)

        var loginParam = DcEnteredLoginParam(addr: emailAddress, password: passwordCell.getText() ?? "")
        loginParam.imapServer = imapServerCell.getText()
        loginParam.imapPort = imapPortCell.getText().flatMap { Int($0) }
        loginParam.imapUser = imapUserCell.getText()
        loginParam.imapSecurity = imapSecurityValue.value
        loginParam.smtpServer = smtpServerCell.getText()
        loginParam.smtpPort = smtpPortCell.getText().flatMap { Int($0) }
        loginParam.smtpUser = smtpUserCell.getText()
        loginParam.smtpPassword = smtpPasswordCell.getText()
        loginParam.smtpSecurity = smtpSecurityValue.value
        loginParam.certificateChecks = certValue

        do {
            _ = try dcContext.addOrUpdateTransport(param: loginParam)
        } catch {
            progressAlertHandler.updateProgressAlert(error: error.localizedDescription)
        }


        self.progressAlertHandler = progressAlertHandler
    }

    private func handleLoginSuccess() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.registerForNotifications()
        appDelegate.prepopulateWidget()

        if let onLoginSuccess {
            onLoginSuccess()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func resignFirstResponderOnAllCells() {
        _ = basicSectionCells.map({
            resignCell(cell: $0)
        })

        _ = advancedSectionCells.map({
            resignCell(cell: $0)
        })
    }

    private func handleLoginButton() {
        loginButton.isEnabled = !(emailCell.getText() ?? "").isEmpty && !(passwordCell.getText() ?? "").isEmpty
    }

    private func handleProviderInfoButton() {
        guard let provider = provider else {
            return
        }
        openProviderInfo(provider: provider)
    }

    func resignCell(cell: UITableViewCell) {
        if let c = cell as? TextFieldCell {
            c.textField.resignFirstResponder()
        }
    }

    @objc private func textFieldDidChange() {
        handleLoginButton()
    }

    @objc private func emailCellEdited() {
        if providerInfoShowing {
            updateProviderInfo()
        }
    }

    // MARK: - coordinator

    private func showProxySettings() {
        let proxySettingsController = ProxySettingsViewController(dcContext: dcContext, dcAccounts: dcAccounts)
        navigationController?.pushViewController(proxySettingsController, animated: true)
    }

    private func showLogViewController() {
        let controller = LogViewController(dcContext: dcContext)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showCertCheckOptions() {
        let certificateCheckController = CertificateCheckViewController(initValue: certValue)
        certificateCheckController.delegate = self
        navigationController?.pushViewController(certificateCheckController, animated: true)
    }

    private func showImapSecurityOptions() {
        let securitySettingsController = SecuritySettingsViewController(initValue: imapSecurityValue.value, title: String.localized("login_imap_security"))
        securitySettingsController.delegate = imapSecurityValue
        navigationController?.pushViewController(securitySettingsController, animated: true)
    }

    private func showSmtpSecurityOptions() {
        let securitySettingsController = SecuritySettingsViewController(initValue: smtpSecurityValue.value, title: String.localized("login_smtp_security"))
        securitySettingsController.delegate = smtpSecurityValue
        navigationController?.pushViewController(securitySettingsController, animated: true)
    }

    private func openProviderInfo(provider: DcProvider) {
        guard let url = URL(string: provider.getOverviewPage) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UITextFieldDelegate
extension EditTransportViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let currentTag = textField.tag
        if let nextField = tableView.viewWithTag(currentTag + 100) as? UITextField {
            nextField.becomeFirstResponder()
            return true
        } else {
            textField.resignFirstResponder()
            let indexPath = IndexPath(row: 0, section: 0)
            tableView.scrollToRow(at: indexPath, at: UITableView.ScrollPosition.top, animated: true)
            return true
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == tagTextFieldEmail {
            updateProviderInfo()
        }
    }
}

extension EditTransportViewController: CertificateCheckDelegate {
    func onCertificateCheckChanged(newValue: String) {
        certValue = newValue
    }
}

class AccountSetupSecurityValue: SecuritySettingsDelegate {
    var value: String

    init() {
        value = "automatic"
    }

    func onSecuritySettingsChanged(newValue: String) {
        value = newValue
    }
}
