import SafariServices
import UIKit

class AccountSetupController: UITableViewController {

    weak var coordinator: AccountSetupCoordinator?

    private let dcContext: DcContext
    private var skipOauth = false
    private var backupProgressObserver: Any?
    private var configureProgressObserver: Any?
    private var oauth2Observer: Any?

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
    private let tagEmptyServerCell = 13
    private let tagDeleteAccountCell = 14
    private let tagRestoreCell = 15

    private let tagTextFieldEmail = 100
    private let tagTextFieldPassword = 200
    private let tagTextFieldImapServer = 300
    private let tagTextFieldImapLogin = 400
    private let tagTextFieldSmtpServer = 500
    private let tagTextFieldSmtpUser = 600
    private let tagTextFieldSmtpPassword = 700

    // add cells to sections

    let basicSection = 100
    let advancedSection = 200
    let restoreSection = 300
    let folderSection = 400
    let dangerSection = 500
    private var sections = [Int]()

    private lazy var basicSectionCells: [UITableViewCell] = [emailCell, passwordCell]
    private lazy var restoreCells: [UITableViewCell] = [restoreCell]
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
        certCheckCell
    ]
    private lazy var folderCells: [UITableViewCell] = [inboxWatchCell, sentboxWatchCell, mvboxWatchCell, sendCopyToSelfCell, mvboxMoveCell]
    private lazy var dangerCells: [UITableViewCell] = [emptyServerCell, deleteAccountCell]

    private let editView: Bool
    private var advancedSectionShowing: Bool = false


    // the progress dialog

    private lazy var configProgressAlert: UIAlertController = {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel, handler: { _ in
            self.dcContext.stopOngoingProcess()
        }))
        return alert
    }()

    private func showProgressHud(title: String) {
        configProgressAlert.actions[0].isEnabled = true
        configProgressAlert.title = title;
        configProgressAlert.message = String.localized("one_moment")
        present(configProgressAlert, animated: true, completion: nil)
    }

    private func updateProgressHud(error message: String?) {
        DispatchQueue.main.async(execute: {
            self.configProgressAlert.dismiss(animated: false)
            let errorAlert = UIAlertController(title: String.localized("error"), message: message, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: String.localized("ok"), style: .default, handler: nil))
            self.present(errorAlert, animated: true, completion: nil)
        })
    }

    private func updateProgressHudSuccess() {
        updateProgressHudValue(value: 1000)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            self.configProgressAlert.dismiss(animated: true) {
                self.handleLoginSuccess()
            }
        })
    }

    private func updateProgressHudValue(value: Int?) {
        if let value = value {
            configProgressAlert.message = String.localized("one_moment") + " " + String(value/10) + "%"
        }
    }

    // cells

    private lazy var emailCell: TextFieldCell = {
        let cell = TextFieldCell.makeEmailCell(delegate: self)
        cell.tag = tagEmailCell
        cell.textField.tag = tagTextFieldEmail // will be used to eventually show oAuth-Dialogue when pressing return key
        cell.setText(text: DcConfig.addr ?? nil)
        cell.textField.delegate = self
        cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        return cell
    }()

    private lazy var passwordCell: TextFieldCell = {
        let cell = TextFieldCell.makePasswordCell(delegate: self)
        cell.tag = tagPasswordCell
        cell.textField.tag = tagTextFieldPassword  // will be used to eventually show oAuth-Dialogue when selecting
        cell.textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        cell.setText(text: DcConfig.mailPw ?? nil)
        cell.textField.delegate = self
        return cell
    }()

    private lazy var restoreCell: UITableViewCell = {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("import_backup_title")
        cell.accessoryType = .disclosureIndicator
        cell.tag = tagRestoreCell
        return cell
    }()

    private lazy var emptyServerCell: ActionCell = {
        let cell = ActionCell(frame: .zero)
        cell.actionTitle = String.localized("pref_empty_server_title")
        cell.actionColor = UIColor.red
        cell.tag = tagEmptyServerCell
        return cell
    }()

    private lazy var deleteAccountCell: ActionCell = {
        let cell = ActionCell(frame: .zero)
        cell.actionTitle = String.localized("delete_account")
        cell.actionColor = UIColor.red
        cell.tag = tagDeleteAccountCell
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
        let cell = TextFieldCell(descriptionID: "login_imap_server",
                                 placeholder: String.localized("automatic"),
                                 delegate: self)
        cell.tag = tagImapServerCell
        cell.setText(text: DcConfig.mailServer ?? nil)
        cell.textField.tag = tagTextFieldImapServer
        cell.textField.autocorrectionType = .no
        cell.textField.spellCheckingType = .no
        cell.textField.autocapitalizationType = .none
        return cell
    }()

    lazy var imapUserCell: TextFieldCell = {
        let cell = TextFieldCell(descriptionID: "login_imap_login", placeholder: String.localized("automatic"), delegate: self)
        cell.setText(text: DcConfig.mailUser ?? nil)
        cell.textField.tag = tagTextFieldImapLogin
        cell.tag = tagImapUserCell
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
        let cell = TextFieldCell(descriptionID: "login_imap_port",
                                 placeholder: String.localized("automatic"),
                                 delegate: self)
        cell.tag = tagImapPortCell
        cell.setText(text: editablePort(port: DcConfig.mailPort))
        cell.textField.tag = tagImapPortCell
        cell.textField.keyboardType = .numberPad
        return cell
    }()

    lazy var imapSecurityCell: UITableViewCell = {
        let text = "\(DcConfig.getImapSecurity())"
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_imap_security")
        cell.accessoryType = .disclosureIndicator
        cell.detailTextLabel?.text = "\(DcConfig.getImapSecurity())"
        cell.selectionStyle = .none
        cell.tag = tagImapSecurityCell
        return cell
    }()

    lazy var smtpServerCell: TextFieldCell = {
        let cell = TextFieldCell(descriptionID: "login_smtp_server",
                                 placeholder: String.localized("automatic"),
                                 delegate: self)
        cell.textField.tag = tagTextFieldSmtpServer
        cell.setText(text: DcConfig.sendServer ?? nil)
        cell.tag = tagSmtpServerCell
        cell.textField.autocorrectionType = .no
        cell.textField.spellCheckingType = .no
        cell.textField.autocapitalizationType = .none
        return cell
    }()

    lazy var smtpUserCell: TextFieldCell = {
        let cell = TextFieldCell(descriptionID: "login_smtp_login", placeholder: String.localized("automatic"), delegate: self)
        cell.textField.tag = tagTextFieldSmtpUser
        cell.setText(text: DcConfig.sendUser ?? nil)
        cell.tag = tagSmtpUserCell
        return cell
    }()

    lazy var smtpPortCell: TextFieldCell = {
        let cell = TextFieldCell(descriptionID: "login_smtp_port",
                                 placeholder: String.localized("automatic"),
                                 delegate: self)
        cell.tag = tagSmtpPortCell
        cell.setText(text: editablePort(port: DcConfig.sendPort))
        cell.textField.tag = tagSmtpPortCell
        cell.textField.keyboardType = .numberPad
        return cell
    }()

    lazy var smtpPasswordCell: TextFieldCell = {
        let cell = TextFieldCell(descriptionID: "login_smtp_password", placeholder: String.localized("automatic"), delegate: self)
        cell.textField.textContentType = UITextContentType.password
        cell.setText(text: DcConfig.sendPw ?? nil)
        cell.textField.isSecureTextEntry = true
        cell.textField.tag = tagTextFieldSmtpPassword
        cell.tag = tagSmtpPasswordCell
        return cell
    }()

    lazy var smtpSecurityCell: UITableViewCell = {
        let security = "\(DcConfig.getSmtpSecurity())"
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_smtp_security")
        cell.detailTextLabel?.text = security
        cell.tag = tagSmtpSecurityCell
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .none
        return cell
    }()

    lazy var certCheckCell: UITableViewCell = {
        let certCheckType = CertificateCheckController.ValueConverter.convertHexToString(value: DcConfig.certificateChecks)
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = String.localized("login_certificate_checks")
        cell.detailTextLabel?.text = certCheckType
        cell.tag = tagCertCheckCell
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .none
        return cell
    }()

    lazy var inboxWatchCell: SwitchCell = {
        return SwitchCell(textLabel: String.localized("pref_watch_inbox_folder"),
                          on: dcContext.getConfigBool("inbox_watch"),
                          action: { cell in
                              self.dcContext.setConfigBool("inbox_watch", cell.isOn)
                          })
    }()

    lazy var sentboxWatchCell: SwitchCell = {
        return SwitchCell(textLabel: String.localized("pref_watch_sent_folder"),
                          on: dcContext.getConfigBool("sentbox_watch"),
                          action: { cell in
                              self.dcContext.setConfigBool("sentbox_watch", cell.isOn)
                          })
    }()

    lazy var mvboxWatchCell: SwitchCell = {
        return SwitchCell(textLabel: String.localized("pref_watch_mvbox_folder"),
                          on: dcContext.getConfigBool("mvbox_watch"),
                          action: { cell in
                              self.dcContext.setConfigBool("mvbox_watch", cell.isOn)
                          })
    }()

    lazy var sendCopyToSelfCell: SwitchCell = {
        return SwitchCell(textLabel: String.localized("pref_send_copy_to_self"),
                          on: dcContext.getConfigBool("bcc_self"),
                          action: { cell in
                              self.dcContext.setConfigBool("bcc_self", cell.isOn)
                          })
    }()

    lazy var mvboxMoveCell: SwitchCell = {
        return SwitchCell(textLabel: String.localized("pref_auto_folder_moves"),
                          on: dcContext.getConfigBool("mvbox_move"),
                          action: { cell in
                              self.dcContext.setConfigBool("mvbox_move", cell.isOn)
                          })
    }()

    private lazy var loginButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: String.localized("login_title"), style: .done, target: self, action: #selector(loginButtonPressed))
        button.isEnabled = dc_is_configured(mailboxPointer) == 0
        return button
    }()

    init(dcContext: DcContext, editView: Bool) {
        self.editView = editView
        self.dcContext = dcContext

        self.sections.append(basicSection)
        self.sections.append(advancedSection)
        if editView {
            self.sections.append(folderSection)
            self.sections.append(dangerSection)
        } else {
            self.sections.append(restoreSection)
        }

        super.init(style: .grouped)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if editView {
            title = String.localized("pref_password_and_account_settings")
        } else {
            title = String.localized("login_header")
        }
        navigationItem.rightBarButtonItem = loginButton
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
    }

    override func viewDidDisappear(_: Bool) {

        let nc = NotificationCenter.default
        if let backupProgressObserver = self.backupProgressObserver {
            nc.removeObserver(backupProgressObserver)
        }
        if let configureProgressObserver = self.configureProgressObserver {
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
        } else if sections[section] == restoreSection {
            return restoreCells.count
        } else if sections[section] == folderSection {
            return folderCells.count
        } else if sections[section] == dangerSection {
            return dangerCells.count
        } else {
            return advancedSectionShowing ? advancedSectionCells.count : 1
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] == basicSection && editView {
            return String.localized("login_header")
        } else if sections[section] == folderSection {
            return String.localized("pref_imap_folder_handling")
        } else if sections[section] == dangerSection {
            return String.localized("danger")
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
                let serverFlags = Int(dcContext.getConfig("configured_server_flags") ?? "") ?? 0
                info += "IMAP "
                info += SecurityConverter.convertHexToString(type: .IMAPSecurity, hex: serverFlags&0x700) + " "
                info += (dcContext.getConfig("configured_mail_user") ?? "unset") + ":***@"
                info += (dcContext.getConfig("configured_mail_server") ?? "unset") + ":"
                info += (dcContext.getConfig("configured_mail_port") ?? "unset") + "\n"
                info += "SMTP "
                info += SecurityConverter.convertHexToString(type: .SMTPSecurity, hex: serverFlags&0x70000) + " "
                info += (dcContext.getConfig("configured_send_user") ?? "unset") + ":***@"
                info += (dcContext.getConfig("configured_send_server") ?? "unset") +  ":"
                info += (dcContext.getConfig("configured_send_port") ?? "unset") + "\n\n"
                info += String.localized("login_subheader")
                return info
            } else {
                return String.localized("login_subheader")
            }
        } else if sections[section] == folderSection {
            return String.localized("pref_auto_folder_moves_explain")
        } else {
            return nil
        }
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section
        let row = indexPath.row

        if sections[section] == basicSection {
            return basicSectionCells[row]
        } else if sections[section] == restoreSection {
            return restoreCells[row]
        } else if sections[section] == folderSection {
            return folderCells[row]
        } else if sections[section] == dangerSection {
            return dangerCells[row]
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
        case tagRestoreCell:
            tableView.reloadData() // otherwise the disclosureIndicator may stay selected
            restoreBackup()
        case tagEmptyServerCell:
            emptyServer()
        case tagDeleteAccountCell:
            deleteAccount()
        case tagAdvancedCell:
            toggleAdvancedSection()
        case tagImapSecurityCell:
            coordinator?.showImapSecurityOptions()
        case tagSmtpSecurityCell:
            coordinator?.showSmptpSecurityOptions()
        case tagCertCheckCell:
            coordinator?.showCertCheckOptions()
        default:
            break
        }
    }

    private func toggleAdvancedSection() {
        let willShow = !advancedSectionShowing

        guard let advancedSectionIndex = sections.firstIndex(of: advancedSection) else { return }
        var advancedIndexPaths: [IndexPath] = advancedSectionCells.indices.map { IndexPath(row: $0, section: advancedSectionIndex) }
        advancedIndexPaths.removeFirst() // do not touch the first item that is the switch itself

        // on expansion, replace the disclosureIndicator by an n-dash
        advancedShowCell.accessoryType = willShow ? .none : .disclosureIndicator
        advancedShowCell.detailTextLabel?.text = willShow ? "\u{2013}" : nil

        advancedSectionShowing = willShow // set flag before delete/insert, because cellForRowAt will be triggered and uses this flag

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

        let oAuthStarted = showOAuthAlertIfNeeded(emailAddress: emailAddress, handleCancel: loginButtonPressed)
        // if canceled we will run this method again but this time oAuthStarted will be false

        if oAuthStarted {
            // the loginFlow will be handled by oAuth2
            return
        }

        let password = passwordCell.getText() ?? "" // empty passwords are ok -> for oauth there is no password needed

        login(emailAddress: emailAddress, password: password)
    }

    private func login(emailAddress: String, password: String, skipAdvanceSetup: Bool = false) {
        addProgressHudLoginListener()
        resignFirstResponderOnAllCells()	// this will resign focus from all textFieldCells so the keyboard wont pop up anymore
        DcConfig.addr = emailAddress
        DcConfig.mailPw = password

        if !skipAdvanceSetup {
            evaluateAdvancedSetup() // this will set MRConfig related to advanced fields
        }

        print("oAuth-Flag when loggin in: \(DcConfig.getAuthFlags())")
        dc_configure(mailboxPointer)
        showProgressHud(title: String.localized("login_header"))
    }

    @objc func closeButtonPressed() {
        dismiss(animated: true, completion: nil)
    }

    // returns true if needed
    private func showOAuthAlertIfNeeded(emailAddress: String, handleCancel: (() -> Void)?) -> Bool {
        return false

        // disable oauth2 for now as not yet supported by deltachat-rust.
        /*
         if skipOauth {
         	// user has previously denied oAuth2-setup
         	return false
         }

         guard let oAuth2UrlPointer = dc_get_oauth2_url(mailboxPointer, emailAddress, "chat.delta:/auth") else {
         	//MRConfig.setAuthFlags(flags: Int(DC_LP_AUTH_NORMAL)) -- do not reset, there may be different values
         	return false
         }

         let oAuth2Url = String(cString: oAuth2UrlPointer)

         if let url = URL(string: oAuth2Url) {
         	let title = "Continue with simplified setup"
         	// swiftlint:disable all
         	let message = "The entered e-mail address supports a simplified setup (oAuth2).\n\nIn the next step, please allow Delta Chat to act as your Chat with E-Mail app.\n\nThere are no Delta Chat servers, your data stays on your device."

         	let oAuthAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
         	let confirm = UIAlertAction(title: "Confirm", style: .default, handler: {
         		[unowned self] _ in
         		let nc = NotificationCenter.default
         		self.oauth2Observer = nc.addObserver(self, selector: #selector(self.oauthLoginApproved), name: NSNotification.Name("oauthLoginApproved"), object: nil)
         		self.launchOAuthBrowserWindow(url: url)
         	})
         	let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: {
         		_ in
         		MRConfig.setAuthFlags(flags: Int(DC_LP_AUTH_NORMAL))
         		self.skipOauth = true
         		handleCancel?()

         	})
         	oAuthAlertController.addAction(confirm)
         	oAuthAlertController.addAction(cancel)

         	present(oAuthAlertController, animated: true, completion: nil)
         	return true
         } else {
         	return false
         }
         */
    }

    @objc func oauthLoginApproved(notification: Notification) {
        guard let userInfo = notification.userInfo, let token = userInfo["token"] as? String, let emailAddress = emailCell.getText() else {
            return
        }
        passwordCell.setText(text: token)
        DcConfig.setAuthFlags(flags: Int(DC_LP_AUTH_OAUTH2))
        login(emailAddress: emailAddress, password: token, skipAdvanceSetup: true)
    }

    private func launchOAuthBrowserWindow(url: URL) {
        UIApplication.shared.open(url) // this opens safari as seperate app
    }

    private func addProgressHudLoginListener() {
        let nc = NotificationCenter.default
        configureProgressObserver = nc.addObserver(
            forName: dcNotificationConfigureProgress,
            object: nil,
            queue: nil
        ) {
            notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.updateProgressHud(error: ui["errorMessage"] as? String)
                } else if ui["done"] as! Bool {
                    self.updateProgressHudSuccess()
                } else {
                    self.updateProgressHudValue(value: ui["progress"] as? Int)
                }
            }
        }
    }

    private func addProgressHudBackupListener() {
        let nc = NotificationCenter.default
        backupProgressObserver = nc.addObserver(
            forName: dcNotificationImexProgress,
            object: nil,
            queue: nil
        ) {
            notification in
            if let ui = notification.userInfo {
                if ui["error"] as! Bool {
                    self.updateProgressHud(error: ui["errorMessage"] as? String)
                } else if ui["done"] as! Bool {
                    self.updateProgressHudSuccess()
                } else {
                    self.updateProgressHudValue(value: ui["progress"] as? Int)
                }
            }
        }
    }

    private func evaluateAdvancedSetup() {
        for cell in advancedSectionCells {
            if let textFieldCell = cell as? TextFieldCell {
                switch  textFieldCell.tag {
                case tagImapServerCell:
                    DcConfig.mailServer = textFieldCell.getText() ?? nil
                case tagImapPortCell:
                    DcConfig.mailPort = textFieldCell.getText() ?? nil
                case tagImapUserCell:
                    DcConfig.mailUser = textFieldCell.getText() ?? nil
                case tagSmtpServerCell:
                    DcConfig.sendServer = textFieldCell.getText() ?? nil
                case tagSmtpPortCell:
                    DcConfig.sendPort = textFieldCell.getText() ?? nil
                case tagSmtpUserCell:
                    DcConfig.sendUser = textFieldCell.getText() ?? nil
                case tagSmtpPasswordCell:
                    DcConfig.sendPw = textFieldCell.getText() ?? nil
                default:
                    logger.info("unknown identifier \(cell.tag)")
                }
            }
        }
    }

    private func restoreBackup() {
        logger.info("restoring backup")
        if DcConfig.configured {
            return
        }
        addProgressHudBackupListener()
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if !documents.isEmpty {
            logger.info("looking for backup in: \(documents[0])")

            if let cString = dc_imex_has_backup(mailboxPointer, documents[0]) {
                let file = String(cString: cString)
                dc_str_unref(cString)
                logger.info("restoring backup: \(file)")
                showProgressHud(title: String.localized("import_backup_title"))
                dc_imex(mailboxPointer, DC_IMEX_IMPORT_BACKUP, file, nil)
            }
            else {
                let alert = UIAlertController(title: String.localized("import_backup_title"),
                    message: String.localizedStringWithFormat(String.localized("import_backup_no_backup_found"),
                        "iTunes / <Your Device> / File Sharing / Delta Chat"), // TOOD: maybe better use an iOS-specific string here
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String.localized("ok"), style: .cancel))
                present(alert, animated: true)
            }
        }

        logger.error("no documents directory found")
    }

    private func emptyServer() {
        let alert = UIAlertController(title: String.localized("pref_empty_server_title"),
            message: String.localized("pref_empty_server_msg"), preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: String.localized("pref_empty_server_inbox"), style: .destructive, handler: { _ in
            self.emptyServer2ndConfirm(title: String.localized("pref_empty_server_inbox"), flags: Int(DC_EMPTY_INBOX))
        }))
        alert.addAction(UIAlertAction(title: String.localized("pref_empty_server_mvbox"), style: .destructive, handler: { _ in
            self.emptyServer2ndConfirm(title: String.localized("pref_empty_server_mvbox"), flags: Int(DC_EMPTY_MVBOX))
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func emptyServer2ndConfirm(title: String, flags: Int) {
        let alert = UIAlertController(title: title,
            message: String.localized("pref_empty_server_msg"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String.localized("pref_empty_server_do_button"), style: .destructive, handler: { _ in
            self.dcContext.emptyServer(flags: flags)
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func deleteAccount() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        let dbfile = appDelegate.dbfile()
        let dburl = URL(fileURLWithPath: dbfile, isDirectory: false)
        let alert = UIAlertController(title: String.localized("delete_account_ask"),
                                      message: nil,
                                      preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: String.localized("delete_account"), style: .destructive, handler: { _ in
            appDelegate.stop()
            appDelegate.close()
            do {
                try FileManager.default.removeItem(at: dburl)
            } catch {
                logger.error("failed to delete db: \(error)")
            }

            appDelegate.open()
            appDelegate.start()

            appDelegate.appCoordinator.presentLoginController()
        }))
        alert.addAction(UIAlertAction(title: String.localized("cancel"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }

    private func handleLoginSuccess() {
        // used when login hud successfully went trough
        dismiss(animated: true, completion: nil)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.registerForPushNotifications()
        initSelectionCells();
        if let onLoginSuccess = self.coordinator?.onLoginSuccess {
            onLoginSuccess()
        } else {
            self.coordinator?.navigateBack()
        }
    }

    private func initSelectionCells() {
        smtpSecurityCell.detailTextLabel?.text = SecurityConverter.convertHexToString(type: .SMTPSecurity, hex: DcConfig.getSmtpSecurity())
        imapSecurityCell.detailTextLabel?.text = SecurityConverter.convertHexToString(type: .IMAPSecurity, hex: DcConfig.getImapSecurity())
        certCheckCell.detailTextLabel?.text = CertificateCheckController.ValueConverter.convertHexToString(value: DcConfig.certificateChecks)
    }

    private func resignFirstResponderOnAllCells() {
        let _ = basicSectionCells.map({
            resignCell(cell: $0)
        })

        let _ = advancedSectionCells.map({
            resignCell(cell: $0)
        }
        )
    }

    private func handleLoginButton() {
        loginButton.isEnabled = !(emailCell.getText() ?? "").isEmpty && !(passwordCell.getText() ?? "").isEmpty
    }

    func resignCell(cell: UITableViewCell) {
        if let c = cell as? TextFieldCell {
            c.textField.resignFirstResponder()
        }
    }

    @objc private func textFieldDidChange() {
        handleLoginButton()
    }
}

extension AccountSetupController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let currentTag = textField.tag
        if let nextField = tableView.viewWithTag(currentTag + 100) as? UITextField {
            if nextField.tag > tagTextFieldPassword, !advancedSectionShowing {
                // gets here when trying to activate a collapsed cell
                return false
            }
            nextField.becomeFirstResponder()
            return true
        } else {
            textField.resignFirstResponder()
            emailCell.textField.becomeFirstResponder()
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
        }
    }
}
