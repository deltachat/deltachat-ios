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
            return String(cString: cString)
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
            return String(cString: cString)
        }
        return "ErrGetMsgInfo"
    }

}

class DcConfig {
    private class func getOptStr(_ key: String) -> String? {
        let p = dc_get_config(mailboxPointer, key)

        if let pSafe = p {
            let c = String(cString: pSafe)
            if c.isEmpty {
                return nil
            }
            return c
        }

        return nil
    }

    private class func setOptStr(_ key: String, _ value: String?) {
        if let v = value {
            dc_set_config(mailboxPointer, key, v)
        } else {
            dc_set_config(mailboxPointer, key, nil)
        }
    }

    private class func getBool(_ key: String) -> Bool {
        return strToBool(getOptStr(key))
    }

    private class func setBool(_ key: String, _ value: Bool) {
        let vStr = value ? "1" : "0"
        setOptStr(key, vStr)
    }

    private class func getInt(_ key: String) -> Int {
        let vStr = getOptStr(key)
        if vStr == nil {
            return 0
        }
        let vInt = Int(vStr!)
        if vInt == nil {
            return 0
        }
        return vInt!
    }

    private class func setInt(_ key: String, _ value: Int) {
        setOptStr(key, String(value))
    }

    class var displayname: String? {
        set { setOptStr("displayname", newValue) }
        get { return getOptStr("displayname") }
    }

    class var selfstatus: String? {
        set { setOptStr("selfstatus", newValue) }
        get { return getOptStr("selfstatus") }
    }

    class var selfavatar: String? {
        set { setOptStr("selfavatar", newValue) }
        get { return getOptStr("selfavatar") }
    }

    class var addr: String? {
        set { setOptStr("addr", newValue) }
        get { return getOptStr("addr") }
    }

    class var mailServer: String? {
        set { setOptStr("mail_server", newValue) }
        get { return getOptStr("mail_server") }
    }

    class var mailUser: String? {
        set { setOptStr("mail_user", newValue) }
        get { return getOptStr("mail_user") }
    }

    class var mailPw: String? {
        set { setOptStr("mail_pw", newValue) }
        get { return getOptStr("mail_pw") }
    }

    class var mailPort: String? {
        set { setOptStr("mail_port", newValue) }
        get { return getOptStr("mail_port") }
    }

    class var sendServer: String? {
        set { setOptStr("send_server", newValue) }
        get { return getOptStr("send_server") }
    }

    class var sendUser: String? {
        set { setOptStr("send_user", newValue) }
        get { return getOptStr("send_user") }
    }

    class var sendPw: String? {
        set { setOptStr("send_pw", newValue) }
        get { return getOptStr("send_pw") }
    }

    class var sendPort: String? {
        set { setOptStr("send_port", newValue) }
        get { return getOptStr("send_port") }
    }

    private class var serverFlags: Int {
        // IMAP-/SMTP-flags as a combination of DC_LP flags
        set {
            setOptStr("server_flags", "\(newValue)")
        }
        get {
            if let str = getOptStr("server_flags") {
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
        set { setBool("e2ee_enabled", newValue) }
        get { return getBool("e2ee_enabled") }
    }

    class var mdnsEnabled: Bool {
        set { setBool("mdns_enabled", newValue) }
        get { return getBool("mdns_enabled") }
    }

    class var inboxWatch: Bool {
        set { setBool("inbox_watch", newValue) }
        get { return getBool("inbox_watch") }
    }

    class var sentboxWatch: Bool {
        set { setBool("sentbox_watch", newValue) }
        get { return getBool("sentbox_watch") }
    }

    class var mvboxWatch: Bool {
        set { setBool("mvbox_watch", newValue) }
        get { return getBool("mvbox_watch") }
    }

    class var mvboxMove: Bool {
        set { setBool("mvbox_move", newValue) }
        get { return getBool("mvbox_move") }
    }

    class var showEmails: Int {
        // one of DC_SHOW_EMAILS_*
        set { setInt("show_emails", newValue) }
        get { return getInt("show_emails") }
    }

    class var saveMimeHeaders: Bool {
        set { setBool("save_mime_headers", newValue) }
        get { return getBool("save_mime_headers") }
    }

    class var configuredEmail: String {
        return getOptStr("configured_addr") ?? ""
    }

    class var configuredMailServer: String {
        return getOptStr("configured_mail_server") ?? ""
    }

    class var configuredMailUser: String {
        return getOptStr("configured_mail_user") ?? ""
    }

    class var configuredMailPw: String {
        return getOptStr("configured_mail_pw") ?? ""
    }

    class var configuredMailPort: String {
        return getOptStr("configured_mail_port") ?? ""
    }

    class var configuredSendServer: String {
        return getOptStr("configured_send_server") ?? ""
    }

    class var configuredSendUser: String {
        return getOptStr("configured_send_user") ?? ""
    }

    class var configuredSendPw: String {
        return getOptStr("configured_send_pw") ?? ""
    }

    class var configuredSendPort: String {
        return getOptStr("configured_send_port") ?? ""
    }

    class var configuredServerFlags: String {
        return getOptStr("configured_server_flags") ?? ""
    }

    class var configured: Bool {
        return getBool("configured")
    }
}

class DcChatlist {
    private var chatListPointer: OpaquePointer?

    var length: Int {
        return dc_chatlist_get_cnt(chatListPointer)
    }

    // takes ownership of specified pointer
    init(chatListPointer: OpaquePointer?) {
        self.chatListPointer = chatListPointer
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

    deinit {
        dc_chatlist_unref(chatListPointer)
    }
}

class DcChat {
    var chatPointer: OpaquePointer?

    var id: Int {
        return Int(dc_chat_get_id(chatPointer))
    }

    var name: String {
        return String(cString: dc_chat_get_name(chatPointer))
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
        let file = dc_chat_get_profile_image(chatPointer)
        if let cFile = file {
            let filename = String(cString: cFile)
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
        }

        return nil
        }()

    var subtitle: String? {
        if let cString = dc_chat_get_subtitle(chatPointer) {
            let str = String(cString: cString)
            return str.isEmpty ? nil : str
        }
        return nil
    }

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
}

class DcMsg: MessageType {
    private var messagePointer: OpaquePointer?

    lazy var sender: SenderType = {
        Sender(id: "\(fromContactId)", displayName: fromContact.name)
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
        guard let result = dc_msg_get_text(messagePointer) else { return nil }

        return String(cString: result)
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
        if let cStr = dc_msg_get_file(messagePointer) {
            let str = String(cString: cStr)

            return str.isEmpty ? nil : str
        }

        return nil
    }

    var filemime: String? {
        if let cStr = dc_msg_get_filemime(messagePointer) {
            let str = String(cString: cStr)

            return str.isEmpty ? nil : str
        }

        return nil
    }

    var filename: String? {
        if let cStr = dc_msg_get_filename(messagePointer) {
            let str = String(cString: cStr)

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

    init(id: Int) {
        messagePointer = dc_get_msg(mailboxPointer, UInt32(id))
    }

    func summary(chars: Int) -> String? {
        guard let result = dc_msg_get_summarytext(messagePointer, Int32(chars)) else { return nil }

        return String(cString: result)
    }

    func createChat() -> DcChat {
        let chatId = dc_create_chat_by_msg_id(mailboxPointer, UInt32(id))
        return DcChat(id: Int(chatId))
    }

    deinit {
        dc_msg_unref(messagePointer)
    }
}

class DcContact {
    private var contactPointer: OpaquePointer?

    var nameNAddr: String {
        return String(cString: dc_contact_get_name_n_addr(contactPointer))
    }

    var name: String {
        return String(cString: dc_contact_get_name(contactPointer))
    }

    var email: String {
        return String(cString: dc_contact_get_addr(contactPointer))
    }

    var isVerified: Bool {
        return dc_contact_is_verified(contactPointer) > 0
    }

    var isBlocked: Bool {
        return dc_contact_is_blocked(contactPointer) == 1
    }

    lazy var profileImage: UIImage? = { [unowned self] in
        let file = dc_contact_get_profile_image(contactPointer)
        if let cFile = file {
            let filename = String(cString: cFile)
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
        }

        return nil
    }()

    var color: UIColor {
        return UIColor(netHex: Int(dc_contact_get_color(contactPointer)))
    }

    var id: Int {
        return Int(dc_contact_get_id(contactPointer))
    }

    init(id: Int) {
        contactPointer = dc_get_contact(mailboxPointer, UInt32(id))
    }

    deinit {
        dc_contact_unref(contactPointer)
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

    init(_ dcLotPointer: OpaquePointer) {
        self.dcLotPointer = dcLotPointer
    }

    deinit {
        dc_lot_unref(dcLotPointer)
    }

    var text1: String? {
        guard let result = dc_lot_get_text1(dcLotPointer) else { return nil }
        return String(cString: result)
    }

    var text1Meaning: Int {
        return Int(dc_lot_get_text1_meaning(dcLotPointer))
    }

    var text2: String? {
        guard let result = dc_lot_get_text2(dcLotPointer) else { return nil }
        return String(cString: result)
    }

    var timestamp: Int {
        return Int(dc_lot_get_timestamp(dcLotPointer))
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
