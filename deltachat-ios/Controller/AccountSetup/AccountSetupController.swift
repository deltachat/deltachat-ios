import SafariServices
import UIKit
import DcCore

class AccountSetupController: UITableViewController, ProgressAlertHandler {
    private var dcContext: DcContext
    private let dcAccounts: DcAccounts
    private var skipOauth = false
    var progressObserver: NSObjectProtocol?
    var onLoginSuccess: (() -> Void)?

    private var oauth2Observer: NSObjectProtocol?

    private let tagEmailCell = 0
    private let tagPasswordCell = 1
    private let tagAdvancedCell = 2
    private let tagImapServerCell = 3
    private let tagImapUserCell = 4
    private let tagImapPortCell = 5
    private let tagImapSecurityCell = 6
    private let tagSmtpServerCell = 7
    private let tagSmtpUserCell = 8
    private let tagSmtpPortCell = 9
    private let tagSmtpPasswordCell = 10
    private let tagSmtpSecurityCell = 11
    private let tagCertCheckCell = 12
    private let tagViewLogCell = 15

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
    let folderSection = 400
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
        viewLogCell
    ]
    private lazy var folderCells: [UITableViewCell] = [sentboxWatchCell, sendCopyToSelfCell, mvboxMoveCell, onlyFetchMvboxCell]
    private let editView: Bool
    private var advancedSectionShowing: Bool = false
    private var providerInfoShowing: Bool = false

    private var provider: DcProvider?

    // MARK: - the progress dialog

    weak var progressAlert: UIAlertController?

    // MARK: - cells

    private lazy var emailCell: TextFieldCell = {
        let cell = TextFieldCell.makeEmailCell(delegate: self)
        cell.tag = tagEmailCell
        cell.textField.addTarget(self, action: #selector(emailCellEdited), for: .editingChanged)
        cell.textField.tag = tagTextFieldEmail // will be used to eventually show oAuth-Dialogue when pressing return key
        cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        cell.textField.returnKeyType = .next
        return cell
    }()

    private lazy var passwordCell: TextFieldCell = {
        let cell = TextFieldCell.makePasswordCell(delegate: self)
        cell.tag = tagPasswordCell
        cell.textField.tag = tagTextFieldPassword  // will be used to eventually show oAuth-Dialogue when selecting
        cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        cell.textField.returnKeyType = advancedSectionShowing ? .next : .default
        return cell
    }()

    private lazy var providerInfoCell: ProviderInfoCell = {
        let cell = ProviderInfoCell()
        cell.onInfoButtonPressed = {
            [weak self] in
            self?.handleProviderInfoButton()
        }
        return cell
    }()

    lazy var advancedShowCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("menu_advanced")
        cell.accessoryType = .disclosureIndicator
        cell.tag = tagAdvancedCell
        return cell
    }()

    lazy var imapServerCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_imap_server",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.tag = tagImapServerCell
        cell.setText(text: dcContext.mailServer ?? nil)
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
        cell.setText(text: dcContext.mailUser ?? nil)
        cell.textField.tag = tagTextFieldImapLogin
        cell.tag = tagImapUserCell
        cell.textField.autocorrectionType = .no
        cell.textField.spellCheckingType = .no
        cell.textField.autocapitalizationType = .none
        cell.textField.returnKeyType = .next
        return cell
    }()

    func editablePort(port: String?) -> String {
        if let port = port {
            if Int(port) == 0 {
                return ""
            }
            return port
        } else {
            return ""
        }
    }

    lazy var imapPortCell: TextFieldCell = {
        let cell = TextFieldCell(
            descriptionID: "login_imap_port",
            placeholder: String.localized("automatic"),
            delegate: self)
        cell.tag = tagImapPortCell
        cell.setText(text: editablePort(port: dcContext.mailPort))
        cell.textField.tag = tagTextFieldImapPort
        cell.textField.keyboardType = .numberPad
        return cell
    }()

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
        cell.setText(text: dcContext.sendServer ?? nil)
        cell.tag = tagSmtpServerCell
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
        cell.setText(text: dcContext.sendUser ?? nil)
        cell.tag = tagSmtpUserCell
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
        cell.tag = tagSmtpPortCell
        cell.setText(text: editablePort(port: dcContext.sendPort))
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
        cell.setText(text: dcContext.sendPw ?? nil)
        cell.textField.isSecureTextEntry = true
        cell.textField.tag = tagTextFieldSmtpPassword
        cell.tag = tagSmtpPasswordCell
        cell.textField.returnKeyType = .next
        return cell
    }()

    lazy var smtpSecurityCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_smtp_security")
        cell.tag = tagSmtpSecurityCell
        cell.accessoryType = .disclosureIndicator
        return cell
    }()

    lazy var certCheckCell: UITableViewCell = {
        let certCheckType = CertificateCheckController.ValueConverter.convertHexToString(value: dcContext.certificateChecks)
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_certificate_checks")
        cell.detailTextLabel?.text = certCheckType
        cell.tag = tagCertCheckCell
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

    lazy var sentboxWatchCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_watch_sent_folder"),
            on: dcContext.getConfigBool("sentbox_watch"),
            action: { cell in
                self.dcAccounts.stopIo()
                self.dcContext.setConfigBool("sentbox_watch", cell.isOn)
                self.dcAccounts.startIo()
        })
    }()

    lazy var sendCopyToSelfCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_send_copy_to_self"),
            on: dcContext.getConfigBool("bcc_self"),
            action: { cell in
                self.dcContext.setConfigBool("bcc_self", cell.isOn)
        })
    }()

    lazy var mvboxMoveCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_auto_folder_moves"),
            on: dcContext.getConfigBool("mvbox_move"),
            action: { cell in
                self.dcAccounts.stopIo()
                self.dcContext.setConfigBool("mvbox_move", cell.isOn)
                self.dcAccounts.startIo()
        })
    }()

    lazy var onlyFetchMvboxCell: SwitchCell = {
        return SwitchCell(
            textLabel: String.localized("pref_only_fetch_mvbox_title"),
            on: dcContext.getConfigBool("only_fetch_mvbox"),
            action: { cell in
                self.dcAccounts.stopIo()
                self.dcContext.setConfigBool("only_fetch_mvbox", cell.isOn)
                self.dcAccounts.startIo()
        })
    }()


    private lazy var loginButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            title: String.localized("login_title"),
            style: .done,
            target: self,
            action: #selector(loginButtonPressed))
        button.isEnabled = !dcContext.isConfigured()
        return button
    }()


    // MARK: - constructor
    init(dcAccounts: DcAccounts, editView: Bool) {
        self.editView = editView
        self.dcAccounts = dcAccounts
        self.dcContext = dcAccounts.getSelected()

        self.sections.append(basicSection)
        self.sections.append(advancedSection)
        if editView {
            self.sections.append(folderSection)
        }

        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if editView {
            title = String.localized("pref_password_and_account_settings")
        } else {
            title = String.localized("login_header")
        }
        navigationItem.rightBarButtonItem = loginButton
        emailCell.setText(text: dcContext.addr ?? nil)
        passwordCell.setText(text: dcContext.mailPw ?? nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        initSelectionCells()
        handleLoginButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        resignFirstResponderOnAllCells()
        progressObserver = nil
    }

    override func viewDidDisappear(_: Bool) {

        let nc = NotificationCenter.default
        if let configureProgressObserver = self.progressObserver {
            nc.removeObserver(configureProgressObserver)
        }
        if let oauth2Observer = self.oauth2Observer {
            nc.removeObserver(oauth2Observer)
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in _: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sections[section] == basicSection {
            return basicSectionCells.count
        } else if sections[section] == folderSection {
            return folderCells.count
        } else {
            return advancedSectionShowing ? advancedSectionCells.count : 1
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == basicSection && editView {
            return String.localized("login_header")
        } else if sections[section] == folderSection {
            return String.localized("pref_imap_folder_handling")
        } else {
            return nil
        }
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        if sections[section] == basicSection {
            return String.localized("login_no_servers_hint")
        } else if sections[section] == advancedSection {
            if advancedSectionShowing && dcContext.isConfigured() {
                var info = String.localized("used_settings") + "\n"
                info += "IMAP "
                info += SecurityConverter.getSocketName(value: Int32(dcContext.getConfigInt("mail_security"))) + " "
                info += (dcContext.getConfig("configured_mail_user") ?? "unset") + ":***@"
                info += (dcContext.getConfig("configured_mail_server") ?? "unset") + ":"
                info += (dcContext.getConfig("configured_mail_port") ?? "unset") + "\n"
                info += "SMTP "
                info += SecurityConverter.getSocketName(value: Int32(dcContext.getConfigInt("send_security"))) + " "
                info += (dcContext.getConfig("configured_send_user") ?? "unset") + ":***@"
                info += (dcContext.getConfig("configured_send_server") ?? "unset") +  ":"
                info += (dcContext.getConfig("configured_send_port") ?? "unset") + "\n\n"
                info += String.localized("login_subheader")
                return info
            } else {
                return String.localized("login_subheader")
            }
        } else if sections[section] == folderSection {
            return String.localized("pref_only_fetch_mvbox_explain")
        } else {
            return nil
        }
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if sections[section] == basicSection {
            return basicSectionCells[row]
        } else if sections[section] == folderSection {
            return folderCells[row]
        } else {
            return advancedSectionCells[row]
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let tappedCell = tableView.cellForRow(at: indexPath) else { return }
        // handle tap on password -> show oAuthDialogue
        switch tappedCell.tag {
        case tagPasswordCell:
            if let textFieldCell = tappedCell as? TextFieldCell {
                if let emailAdress = textFieldCell.getText() {
                    _ = showOAuthAlertIfNeeded(emailAddress: emailAdress, handleCancel: nil)
                }
            }
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
        tableView.reloadData() // needed to force a redraw
    }

    @objc private func loginButtonPressed() {
        guard let emailAddress = emailCell.getText() else {
            return // handle case when either email or pw fields are empty
        }

        func loginButtonPressedContinue() {
            let oAuthStarted = showOAuthAlertIfNeeded(emailAddress: emailAddress, handleCancel: loginButtonPressed)
            // if canceled we will run this method again but this time oAuthStarted will be false

            if oAuthStarted {
                // the loginFlow will be handled by oAuth2
                return
            }

            let password = passwordCell.getText() ?? "" // empty passwords are ok -> for oauth there is no password needed

            login(emailAddress: emailAddress, password: password)
        }

        if dcContext.isConfigured(),
           let oldAddress = dcContext.getConfig("configured_addr"),
           oldAddress != emailAddress {
            let msg = String.localizedStringWithFormat(String.localized("aeap_explanation"), oldAddress, emailAddress)
            let alert = UIAlertController(title: msg, message: nil, preferredStyle: .safeActionSheet)
            alert.addAction(UIAlertAction(title: String.localized("perm_continue"), style: .default, handler: { _ in
                loginButtonPressedContinue()
            }))
            alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        } else {
            loginButtonPressedContinue()
        }
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

    private func login(emailAddress: String, password: String, skipAdvanceSetup: Bool = false) {
        addProgressHudLoginListener()
        resignFirstResponderOnAllCells()	// this will resign focus from all textFieldCells so the keyboard wont pop up anymore
        dcContext.addr = emailAddress
        dcContext.mailPw = password

        if !skipAdvanceSetup {
            evaluateAdvancedSetup() // this will set MRConfig related to advanced fields
        }

        print("oAuth-Flag when loggin in: \(dcContext.getAuthFlags())")
        dcAccounts.stopIo()
        dcContext.configure()
        showProgressAlert(title: String.localized("login_header"), dcContext: dcContext)
    }

    @objc func closeButtonPressed() {
        dismiss(animated: true, completion: nil)
    }

    // returns true if needed
    private func showOAuthAlertIfNeeded(emailAddress: String, handleCancel: (() -> Void)?) -> Bool {
        return false

        // don't use oauth2 for now as not yet supported by deltachat-rust.
//
//         if skipOauth {
//             // user has previously denied oAuth2-setup
//             return false
//         }
//
//         guard let oAuth2UrlPointer = dc_get_oauth2_url(mailboxPointer, emailAddress, "chat.delta:/auth") else {
//             //MRConfig.setAuthFlags(flags: Int(DC_LP_AUTH_NORMAL)) -- do not reset, there may be different values
//             return false
//         }
//
//         let oAuth2Url = String(cString: oAuth2UrlPointer)
//
//         if let url = URL(string: oAuth2Url) {
//             let title = "Continue with simplified setup"
//             // swiftlint:disable all
//             let message = "The entered e-mail address supports a simplified setup (oAuth2).\n\nIn the next step, please allow Delta Chat to act as your Chat with E-Mail app.\n\nThere are no Delta Chat servers, your data stays on your device."
//
//             let oAuthAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
//             let confirm = UIAlertAction(title: "Confirm", style: .default, handler: {
//                 [weak self] _ in // TODO: refactor usages of `self` to `self?` when this code is used again
//                 let nc = NotificationCenter.default
//                 self.oauth2Observer = nc.addObserver(self, selector: #selector(self.oauthLoginApproved), name: NSNotification.Name("oauthLoginApproved"), object: nil)
//                 self.launchOAuthBrowserWindow(url: url)
//             })
//             let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: {
//                 _ in
//                 MRConfig.setAuthFlags(flags: Int(DC_LP_AUTH_NORMAL))
//                 self.skipOauth = true
//                 handleCancel?()
//
//             })
//             oAuthAlertController.addAction(confirm)
//             oAuthAlertController.addAction(cancel)
//
//             present(oAuthAlertController, animated: true, completion: nil)
//             return true
//         } else {
//             return false
//         }
    }

    @objc func oauthLoginApproved(notification: Notification) {
        guard let userInfo = notification.userInfo, let token = userInfo["token"] as? String, let emailAddress = emailCell.getText() else {
            return
        }
        passwordCell.setText(text: token)
        dcContext.setAuthFlags(flags: Int(DC_LP_AUTH_OAUTH2))
        login(emailAddress: emailAddress, password: token, skipAdvanceSetup: true)
    }

    private func launchOAuthBrowserWindow(url: URL) {
        UIApplication.shared.open(url) // this opens safari as seperate app
    }

    private func addProgressHudLoginListener() {

        let nc = NotificationCenter.default
        progressObserver = nc.addObserver(
            forName: dcNotificationConfigureProgress,
            object: nil,
            queue: nil
        ) {
            notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.dcAccounts.startIo()
                    var errorMessage = ui["errorMessage"] as? String
                    if let appDelegate = UIApplication.shared.delegate as? AppDelegate, appDelegate.reachability.connection == .none {
                        errorMessage = String.localized("login_error_no_internet_connection")
                    } else {
                        errorMessage = "\(errorMessage ?? "no message")\n\n(warning=\(self.dcContext.lastWarningString) (progress=\(self.dcContext.maxConfigureProgress))"
                    }
                    self.updateProgressAlert(error: errorMessage)
                } else if ui["done"] as! Bool {
                    self.dcAccounts.startIo()
                    self.updateProgressAlertSuccess(completion: self.handleLoginSuccess)
                } else {
                    self.updateProgressAlertValue(value: ui["progress"] as? Int)
                }
            }
        }
    }

    private func evaluateAdvancedSetup() {
        for cell in advancedSectionCells {
            if let textFieldCell = cell as? TextFieldCell {
                switch  textFieldCell.tag {
                case tagImapServerCell:
                    dcContext.mailServer = textFieldCell.getText() ?? nil
                case tagImapPortCell:
                    dcContext.mailPort = textFieldCell.getText() ?? nil
                case tagImapUserCell:
                    dcContext.mailUser = textFieldCell.getText() ?? nil
                case tagSmtpServerCell:
                    dcContext.sendServer = textFieldCell.getText() ?? nil
                case tagSmtpPortCell:
                    dcContext.sendPort = textFieldCell.getText() ?? nil
                case tagSmtpUserCell:
                    dcContext.sendUser = textFieldCell.getText() ?? nil
                case tagSmtpPasswordCell:
                    dcContext.sendPw = textFieldCell.getText() ?? nil
                default:
                    logger.info("unknown identifier \(cell.tag)")
                }
            }
        }
    }

    private func handleLoginSuccess() {
        // used when login hud successfully went through
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        if !UserDefaults.standard.bool(forKey: "notifications_disabled") {
            appDelegate.registerForNotifications()
        }

        initSelectionCells();
        if let onLoginSuccess = self.onLoginSuccess {
            onLoginSuccess()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func initSelectionCells() {
        imapSecurityCell.detailTextLabel?.text = SecurityConverter.getSocketName(value: Int32(dcContext.getConfigInt("mail_security")))
        smtpSecurityCell.detailTextLabel?.text = SecurityConverter.getSocketName(value: Int32(dcContext.getConfigInt("send_security")))
        certCheckCell.detailTextLabel?.text = CertificateCheckController.ValueConverter.convertHexToString(value: dcContext.certificateChecks)
    }

    private func resignFirstResponderOnAllCells() {
        let _ = basicSectionCells.map({
            resignCell(cell: $0)
        })

        let _ = advancedSectionCells.map({
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

    private func showLogViewController() {
        let controller = LogViewController(dcContext: dcContext)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func showCertCheckOptions() {
        let certificateCheckController = CertificateCheckController(dcContext: dcContext, sectionTitle: String.localized("login_certificate_checks"))
        navigationController?.pushViewController(certificateCheckController, animated: true)
    }

    private func showImapSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(dcContext: dcContext, title: String.localized("login_imap_security"),
                                                                      type: SecurityType.IMAPSecurity)
        navigationController?.pushViewController(securitySettingsController, animated: true)
    }

    private func showSmtpSecurityOptions() {
        let securitySettingsController = SecuritySettingsController(dcContext: dcContext,
                                                                    title: String.localized("login_smtp_security"),
                                                                    type: SecurityType.SMTPSecurity)
        navigationController?.pushViewController(securitySettingsController, animated: true)
    }

    private func openProviderInfo(provider: DcProvider) {
        guard let url = URL(string: provider.getOverviewPage) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UITextFieldDelegate
extension AccountSetupController: UITextFieldDelegate {
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

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField.tag == tagTextFieldEmail {
            // this will re-enable possible oAuth2-login
            skipOauth = false
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.tag == tagTextFieldEmail {
            let _ = showOAuthAlertIfNeeded(emailAddress: textField.text ?? "", handleCancel: {
                self.passwordCell.textField.becomeFirstResponder()
            })
            updateProviderInfo()
        }
    }
}
