import Foundation
import MessageKit
import UIKit

class DcContext {
    let contextPointer: OpaquePointer?

    init() {
        contextPointer = dc_context_new(callback_ios, nil, "iOS")
    }

    deinit {
        dc_context_unref(contextPointer)
    }

    func deleteContact(contactId: Int) {
        dc_delete_contact(self.contextPointer, UInt32(contactId))
    }

    func getChatlist(flags: Int32, queryString: String?, queryId: Int) -> DcChatlist {
        let chatlistPointer = dc_get_chatlist(contextPointer, flags, queryString, UInt32(queryId))
        let chatlist = DcChatlist(chatListPointer: chatlistPointer)
        return chatlist
    }

    func deleteChat(chatId: Int) {
        dc_delete_chat(self.contextPointer, UInt32(chatId))
    }

    func archiveChat(chatId: Int, archive: Bool) {
        dc_archive_chat(self.contextPointer, UInt32(chatId), Int32(archive ? 1 : 0))
    }

    func getSecurejoinQr (chatId: Int) -> String? {
        if let cString = dc_get_securejoin_qr(self.contextPointer, UInt32(chatId)) {
            let swiftString = String(cString: cString)
            free(cString)
            return swiftString
        }
        return nil
    }

    func joinSecurejoin (qrCode: String) -> Int {
        return Int(dc_join_securejoin(contextPointer, qrCode))
    }

    func checkQR(qrCode: String) -> DcLot {
        return DcLot(dc_check_qr(contextPointer, qrCode))
    }

    func stopOngoingProcess() {
        dc_stop_ongoing_process(contextPointer)
    }

    func getMsgInfo(msgId: Int) -> String {
        if let cString = dc_get_msg_info(self.contextPointer, UInt32(msgId)) {
            let swiftString = String(cString: cString)
            free(cString)
            return swiftString
        }
        return "ErrGetMsgInfo"
    }

}

class DcConfig {
    private class func getConfig(_ key: String) -> String? {
        guard let cString = dc_get_config(mailboxPointer, key) else { return nil }
        let value = String(cString: cString)
        free(cString)
        if value.isEmpty {
            return nil
        }
        return value
    }

    private class func setConfig(_ key: String, _ value: String?) {
        if let v = value {
            dc_set_config(mailboxPointer, key, v)
        } else {
            dc_set_config(mailboxPointer, key, nil)
        }
    }

    private class func getConfigBool(_ key: String) -> Bool {
        return strToBool(getConfig(key))
    }

    private class func setConfigBool(_ key: String, _ value: Bool) {
        let vStr = value ? "1" : "0"
        setConfig(key, vStr)
    }

    private class func getConfigInt(_ key: String) -> Int {
        let vStr = getConfig(key)
        if vStr == nil {
            return 0
        }
        let vInt = Int(vStr!)
        if vInt == nil {
            return 0
        }
        return vInt!
    }

    private class func setConfigInt(_ key: String, _ value: Int) {
        setConfig(key, String(value))
    }

    class var displayname: String? {
        set { setConfig("displayname", newValue) }
        get { return getConfig("displayname") }
    }

    class var selfstatus: String? {
        set { setConfig("selfstatus", newValue) }
        get { return getConfig("selfstatus") }
    }

    class var selfavatar: String? {
        set { setConfig("selfavatar", newValue) }
        get { return getConfig("selfavatar") }
    }

    class var addr: String? {
        set { setConfig("addr", newValue) }
        get { return getConfig("addr") }
    }

    class var mailServer: String? {
        set { setConfig("mail_server", newValue) }
        get { return getConfig("mail_server") }
    }

    class var mailUser: String? {
        set { setConfig("mail_user", newValue) }
        get { return getConfig("mail_user") }
    }

    class var mailPw: String? {
        set { setConfig("mail_pw", newValue) }
        get { return getConfig("mail_pw") }
    }

    class var mailPort: String? {
        set { setConfig("mail_port", newValue) }
        get { return getConfig("mail_port") }
    }

    class var sendServer: String? {
        set { setConfig("send_server", newValue) }
        get { return getConfig("send_server") }
    }

    class var sendUser: String? {
        set { setConfig("send_user", newValue) }
        get { return getConfig("send_user") }
    }

    class var sendPw: String? {
        set { setConfig("send_pw", newValue) }
        get { return getConfig("send_pw") }
    }

    class var sendPort: String? {
        set { setConfig("send_port", newValue) }
        get { return getConfig("send_port") }
    }

    private class var serverFlags: Int {
        // IMAP-/SMTP-flags as a combination of DC_LP flags
        set {
            setConfig("server_flags", "\(newValue)")
        }
        get {
            if let str = getConfig("server_flags") {
                return Int(str) ?? 0
            } else {
                return 0
            }
        }
    }

    class func setImapSecurity(imapFlags flags: Int) {
        var sf = serverFlags
        sf = sf & ~0x700 // DC_LP_IMAP_SOCKET_FLAGS
        sf = sf | flags
        serverFlags = sf
    }

    class func setSmtpSecurity(smptpFlags flags: Int) {
        var sf = serverFlags
        sf = sf & ~0x70000 // DC_LP_SMTP_SOCKET_FLAGS
        sf = sf | flags
        serverFlags = sf
    }

    class func setAuthFlags(flags: Int) {
        var sf = serverFlags
        sf = sf & ~0x6 // DC_LP_AUTH_FLAGS
        sf = sf | flags
        serverFlags = sf
    }

    class func getImapSecurity() -> Int {
        var sf = serverFlags
        sf = sf & 0x700 // DC_LP_IMAP_SOCKET_FLAGS
        return sf
    }

    class func getSmtpSecurity() -> Int {
        var sf = serverFlags
        sf = sf & 0x70000  // DC_LP_SMTP_SOCKET_FLAGS
        return sf
    }

    class func getAuthFlags() -> Int {
        var sf = serverFlags
        sf = sf & 0x6 // DC_LP_AUTH_FLAGS
        serverFlags = sf
        return sf
    }

    class var e2eeEnabled: Bool {
        set { setConfigBool("e2ee_enabled", newValue) }
        get { return getConfigBool("e2ee_enabled") }
    }

    class var mdnsEnabled: Bool {
        set { setConfigBool("mdns_enabled", newValue) }
        get { return getConfigBool("mdns_enabled") }
    }

    class var inboxWatch: Bool {
        set { setConfigBool("inbox_watch", newValue) }
        get { return getConfigBool("inbox_watch") }
    }

    class var sentboxWatch: Bool {
        set { setConfigBool("sentbox_watch", newValue) }
        get { return getConfigBool("sentbox_watch") }
    }

    class var mvboxWatch: Bool {
        set { setConfigBool("mvbox_watch", newValue) }
        get { return getConfigBool("mvbox_watch") }
    }

    class var mvboxMove: Bool {
        set { setConfigBool("mvbox_move", newValue) }
        get { return getConfigBool("mvbox_move") }
    }

    class var showEmails: Int {
        // one of DC_SHOW_EMAILS_*
        set { setConfigInt("show_emails", newValue) }
        get { return getConfigInt("show_emails") }
    }

    class var configuredEmail: String {
        return getConfig("configured_addr") ?? ""
    }

    class var configuredMailServer: String {
        return getConfig("configured_mail_server") ?? ""
    }

    class var configuredMailUser: String {
        return getConfig("configured_mail_user") ?? ""
    }

    class var configuredMailPw: String {
        return getConfig("configured_mail_pw") ?? ""
    }

    class var configuredMailPort: String {
        return getConfig("configured_mail_port") ?? ""
    }

    class var configuredSendServer: String {
        return getConfig("configured_send_server") ?? ""
    }

    class var configuredSendUser: String {
        return getConfig("configured_send_user") ?? ""
    }

    class var configuredSendPw: String {
        return getConfig("configured_send_pw") ?? ""
    }

    class var configuredSendPort: String {
        return getConfig("configured_send_port") ?? ""
    }

    class var configuredServerFlags: String {
        return getConfig("configured_server_flags") ?? ""
    }

    class var configured: Bool {
        return getConfigBool("configured")
    }
}

class DcChatlist {
    private var chatListPointer: OpaquePointer?

    // takes ownership of specified pointer
    init(chatListPointer: OpaquePointer?) {
        self.chatListPointer = chatListPointer
    }

    deinit {
        dc_chatlist_unref(chatListPointer)
    }

    var length: Int {
        return dc_chatlist_get_cnt(chatListPointer)
    }

    func getChatId(index: Int) -> Int {
        return Int(dc_chatlist_get_chat_id(chatListPointer, index))
    }

    func getMsgId(index: Int) -> Int {
        return Int(dc_chatlist_get_msg_id(chatListPointer, index))
    }

    func getSummary(index: Int) -> DcLot {
        guard let lotPointer = dc_chatlist_get_summary(self.chatListPointer, index, nil) else {
            fatalError("lot-pointer was nil")
        }
        return DcLot(lotPointer)
    }
}

class DcChat {
    var chatPointer: OpaquePointer?

    init(id: Int) {
        if let p = dc_get_chat(mailboxPointer, UInt32(id)) {
            chatPointer = p
        } else {
            fatalError("Invalid chatID opened \(id)")
        }
    }

    deinit {
        dc_chat_unref(chatPointer)
    }

    var id: Int {
        return Int(dc_chat_get_id(chatPointer))
    }

    var name: String {
        guard let cString = dc_chat_get_name(chatPointer) else { return "" }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var type: Int {
        return Int(dc_chat_get_type(chatPointer))
    }

    var chatType: ChatType {
        return ChatType(rawValue: type) ?? ChatType.GROUP // group as fallback - shouldn't get here
    }

    var color: UIColor {
        return UIColor(netHex: Int(dc_chat_get_color(chatPointer)))
    }

    var isVerified: Bool {
        return dc_chat_is_verified(chatPointer) > 0
    }

    var contactIds: [Int] {
        return Utils.copyAndFreeArray(inputArray: dc_get_chat_contacts(mailboxPointer, UInt32(id)))
    }

    lazy var profileImage: UIImage? = { [unowned self] in
        guard let cString = dc_chat_get_profile_image(chatPointer) else { return nil }
        let filename = String(cString: cString)
        free(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        if path.isFileURL {
            do {
                let data = try Data(contentsOf: path)
                let image = UIImage(data: data)
                return image
            } catch {
                logger.warning("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
        }()

    var subtitle: String? {
        if let cString = dc_chat_get_subtitle(chatPointer) {
            let str = String(cString: cString)
            free(cString)
            return str.isEmpty ? nil : str
        }
        return nil
    }
}

class DcMsg: MessageType {
    private var messagePointer: OpaquePointer?

    init(id: Int) {
        messagePointer = dc_get_msg(mailboxPointer, UInt32(id))
    }

    deinit {
        dc_msg_unref(messagePointer)
    }

    lazy var sender: SenderType = {
        Sender(id: "\(fromContactId)", displayName: fromContact.displayName)
    }()

    lazy var sentDate: Date = {
        Date(timeIntervalSince1970: Double(timestamp))
    }()

    let localDateFormatter: DateFormatter = {
        let result = DateFormatter()
        result.dateStyle = .none
        result.timeStyle = .short
        return result
    }()

    func formattedSentDate() -> String {
        return localDateFormatter.string(from: sentDate)
    }

    lazy var kind: MessageKind = {
        if isInfo {
            let text = NSAttributedString(string: self.text ?? "", attributes: [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: UIColor.darkGray,
                ])
            return MessageKind.attributedText(text)
        }

        let text = self.text ?? ""

        if self.viewtype == nil {
            return MessageKind.text(text)
        }

        switch self.viewtype! {
        case .image:
            return MessageKind.photo(Media(image: image))
        case .video:
            return MessageKind.video(Media(url: fileURL))
        default:
            // TODO: custom views for audio, etc
            if let filename = self.filename {
                return MessageKind.text("File: \(self.filename ?? "") (\(self.filesize) bytes)")
            }
            return MessageKind.text(text)
        }
    }()

    var messageId: String {
        return "\(id)"
    }

    var id: Int {
        return Int(dc_msg_get_id(messagePointer))
    }

    var fromContactId: Int {
        return Int(dc_msg_get_from_id(messagePointer))
    }

    lazy var fromContact: DcContact = {
        DcContact(id: fromContactId)
    }()

    var chatId: Int {
        return Int(dc_msg_get_chat_id(messagePointer))
    }

    var text: String? {
        guard let cString = dc_msg_get_text(messagePointer) else { return nil }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var viewtype: MessageViewType? {
        switch dc_msg_get_viewtype(messagePointer) {
        case 0:
            return nil
        case DC_MSG_AUDIO:
            return .audio
        case DC_MSG_FILE:
            return .file
        case DC_MSG_GIF:
            return .gif
        case DC_MSG_TEXT:
            return .text
        case DC_MSG_IMAGE:
            return .image
        case DC_MSG_VIDEO:
            return .video
        case DC_MSG_VOICE:
            return .voice
        default:
            return nil
        }
    }

    var fileURL: URL? {
        if let file = self.file {
            return URL(fileURLWithPath: file, isDirectory: false)
        }
        return nil
    }

    private lazy var image: UIImage? = { [unowned self] in
        let filetype = dc_msg_get_viewtype(messagePointer)
        if let path = fileURL, filetype == DC_MSG_IMAGE {
            if path.isFileURL {
                do {
                    let data = try Data(contentsOf: path)
                    let image = UIImage(data: data)
                    return image
                } catch {
                    logger.warning("failed to load image: \(path), \(error)")
                    return nil
                }
            }
            return nil
        } else {
            return nil
        }
        }()

    var file: String? {
        if let cString = dc_msg_get_file(messagePointer) {
            let str = String(cString: cString)
            free(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    var filemime: String? {
        if let cString = dc_msg_get_filemime(messagePointer) {
            let str = String(cString: cString)
            free(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    var filename: String? {
        if let cString = dc_msg_get_filename(messagePointer) {
            let str = String(cString: cString)
            free(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    var filesize: Int {
        return Int(dc_msg_get_filebytes(messagePointer))
    }

    // DC_MSG_*
    var type: Int {
        return Int(dc_msg_get_viewtype(messagePointer))
    }

    // DC_STATE_*
    var state: Int {
        return Int(dc_msg_get_state(messagePointer))
    }

    func stateDescription() -> String {
        switch Int32(state) {
        case DC_STATE_IN_FRESH:
            return "Fresh"
        case DC_STATE_IN_NOTICED:
            return "Noticed"
        case DC_STATE_IN_SEEN:
            return "Seen"
        case DC_STATE_OUT_DRAFT:
            return "Draft"
        case DC_STATE_OUT_PENDING:
            return "Pending"
        case DC_STATE_OUT_DELIVERED:
            return "Sent"
        case DC_STATE_OUT_MDN_RCVD:
            return "Read"
        case DC_STATE_OUT_FAILED:
            return "Failed"
        default:
            return "Unknown"
        }
    }

    var timestamp: Int64 {
        return Int64(dc_msg_get_timestamp(messagePointer))
    }

    var isInfo: Bool {
        return dc_msg_is_info(messagePointer) == 1
    }

    func summary(chars: Int) -> String? {
        guard let cString = dc_msg_get_summarytext(messagePointer, Int32(chars)) else { return nil }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    func createChat() -> DcChat {
        let chatId = dc_create_chat_by_msg_id(mailboxPointer, UInt32(id))
        return DcChat(id: Int(chatId))
    }
}

class DcContact {
    private var contactPointer: OpaquePointer?

    init(id: Int) {
        contactPointer = dc_get_contact(mailboxPointer, UInt32(id))
    }

    deinit {
        dc_contact_unref(contactPointer)
    }

    var displayName: String {
        guard let cString = dc_contact_get_display_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var nameNAddr: String {
        guard let cString = dc_contact_get_name_n_addr(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var name: String {
        guard let cString = dc_contact_get_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var email: String {
        guard let cString = dc_contact_get_addr(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var isVerified: Bool {
        return dc_contact_is_verified(contactPointer) > 0
    }

    var isBlocked: Bool {
        return dc_contact_is_blocked(contactPointer) == 1
    }

    lazy var profileImage: UIImage? = { [unowned self] in
        guard let cString = dc_contact_get_profile_image(contactPointer) else { return nil }
        let filename = String(cString: cString)
        free(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        if path.isFileURL {
            do {
                let data = try Data(contentsOf: path)
                return UIImage(data: data)
            } catch {
                logger.warning("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
    }()

    var color: UIColor {
        return UIColor(netHex: Int(dc_contact_get_color(contactPointer)))
    }

    var id: Int {
        return Int(dc_contact_get_id(contactPointer))
    }

    func block() {
        dc_block_contact(mailboxPointer, UInt32(id), 1)
    }

    func unblock() {
        dc_block_contact(mailboxPointer, UInt32(id), 0)
    }

    func marknoticed() {
        dc_marknoticed_contact(mailboxPointer, UInt32(id))
    }
}

class DcLot {
    private var dcLotPointer: OpaquePointer?

    // takes ownership of specified pointer
    init(_ dcLotPointer: OpaquePointer) {
        self.dcLotPointer = dcLotPointer
    }

    deinit {
        dc_lot_unref(dcLotPointer)
    }

    var text1: String? {
        guard let cString = dc_lot_get_text1(dcLotPointer) else { return nil }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var text1Meaning: Int {
        return Int(dc_lot_get_text1_meaning(dcLotPointer))
    }

    var text2: String? {
        guard let cString = dc_lot_get_text2(dcLotPointer) else { return nil }
        let swiftString = String(cString: cString)
        free(cString)
        return swiftString
    }

    var timestamp: Int64 {
        return Int64(dc_lot_get_timestamp(dcLotPointer))
    }

    var state: Int {
        return Int(dc_lot_get_state(dcLotPointer))
    }

    var id: Int {
        return Int(dc_lot_get_id(dcLotPointer))
    }
}

enum ChatType: Int {
    case SINGLE = 100
    case GROUP = 120
    case VERYFIEDGROUP = 130
}

enum MessageViewType: CustomStringConvertible {
    case audio
    case file
    case gif
    case image
    case text
    case video
    case voice

    var description: String {
        switch self {
        // Use Internationalization, as appropriate.
        case .audio: return "Audio"
        case .file: return "File"
        case .gif: return "GIF"
        case .image: return "Image"
        case .text: return "Text"
        case .video: return "Video"
        case .voice: return "Voice"
        }
    }
}

func strToBool(_ value: String?) -> Bool {
    if let vStr = value {
        if let vInt = Int(vStr) {
            return vInt == 1
        }
        return false
    }

    return false
}
