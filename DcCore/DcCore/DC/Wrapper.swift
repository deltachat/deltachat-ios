import Foundation
import UIKit
import AVFoundation

class DcContext {
    /// TODO: THIS global instance should be replaced in the future, for example for a multi-account scenario,
    /// where we want to have more than one DcContext.
    static let dcContext: DcContext = DcContext()
    var logger: Logger?
    let contextPointer: OpaquePointer
    var lastErrorString: String?

    private init() {
        var version = ""
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version += " " + appVersion
        }

        contextPointer = dc_context_new(callback_ios, nil, "iOS" + version)
    }

    deinit {
        dc_context_unref(contextPointer)
    }

    /// Injection of DcContext is preferred over the usage of the shared variable
    static var shared: DcContext {
        return .dcContext
    }

    func createContact(name: String, email: String) -> Int {
        return Int(dc_create_contact(contextPointer, name, email))
    }

    func deleteContact(contactId: Int) -> Bool {
        return dc_delete_contact(self.contextPointer, UInt32(contactId)) == 1
    }

    func getContacts(flags: Int32, queryString: String? = nil) -> [Int] {
        let cContacts = dc_get_contacts(contextPointer, UInt32(flags), queryString)
        return Utils.copyAndFreeArray(inputArray: cContacts)
    }

    func getBlockedContacts() -> [Int] {
        let cBlockedContacts = dc_get_blocked_contacts(contextPointer)
        return Utils.copyAndFreeArray(inputArray: cBlockedContacts)
    }

    func addContacts(contactString: String) {
        dc_add_address_book(contextPointer, contactString)
    }

    func getChat(chatId: Int) -> DcChat {
        return DcChat(id: chatId)
    }

    func getChatIdByContactId(_ contactId: Int) -> Int? {
        let chatId = dc_get_chat_id_by_contact_id(contextPointer, UInt32(contactId))
        if chatId == 0 {
            return nil
        } else {
            return Int(chatId)
        }
    }

    func createChatByMessageId(_ messageId: Int) -> DcChat {
        let chatId = dc_create_chat_by_msg_id(contextPointer, UInt32(messageId))
        return DcChat(id: Int(chatId))
    }

    func getChatlist(flags: Int32, queryString: String?, queryId: Int) -> DcChatlist {
        let chatlistPointer = dc_get_chatlist(contextPointer, flags, queryString, UInt32(queryId))
        let chatlist = DcChatlist(chatListPointer: chatlistPointer)
        return chatlist
    }

    func getChatMedia(chatId: Int, messageType: Int32, messageType2: Int32, messageType3: Int32) -> [Int] {
        guard let messagesPointer = dc_get_chat_media(contextPointer, UInt32(chatId), messageType, messageType2, messageType3) else {
            return []
        }

        let messageIds: [Int] =  Utils.copyAndFreeArray(inputArray: messagesPointer)
        return messageIds
    }

    @discardableResult
    func createChatByContactId(contactId: Int) -> Int {
        return Int(dc_create_chat_by_contact_id(contextPointer, UInt32(contactId)))
    }

    func getChatIdByContactId(contactId: Int) -> Int {
        return Int(dc_get_chat_id_by_contact_id(contextPointer, UInt32(contactId)))
    }

    func createGroupChat(verified: Bool, name: String) -> Int {
        return Int(dc_create_group_chat(contextPointer, verified ? 1 : 0, name))
    }

    func addContactToChat(chatId: Int, contactId: Int) -> Bool {
        return dc_add_contact_to_chat(contextPointer, UInt32(chatId), UInt32(contactId)) == 1
    }

    func removeContactFromChat(chatId: Int, contactId: Int) -> Bool {
        return dc_remove_contact_from_chat(contextPointer, UInt32(chatId), UInt32(contactId)) == 1
    }

    func setChatName(chatId: Int, name: String) -> Bool {
        return dc_set_chat_name(contextPointer, UInt32(chatId), name) == 1
    }

    func deleteChat(chatId: Int) {
        dc_delete_chat(contextPointer, UInt32(chatId))
    }

    func archiveChat(chatId: Int, archive: Bool) {
        dc_set_chat_visibility(contextPointer, UInt32(chatId), Int32(archive ? DC_CHAT_VISIBILITY_ARCHIVED : DC_CHAT_VISIBILITY_NORMAL))
    }

    func setChatVisibility(chatId: Int, visibility: Int32) {
        dc_set_chat_visibility(contextPointer, UInt32(chatId), visibility)
    }

    func marknoticedChat(chatId: Int) {
        dc_marknoticed_chat(self.contextPointer, UInt32(chatId))
    }

    func getSecurejoinQr (chatId: Int) -> String? {
        if let cString = dc_get_securejoin_qr(self.contextPointer, UInt32(chatId)) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
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

    func getInfo() -> [[String]] {
        if let cString = dc_get_info(contextPointer) {
            let info = String(cString: cString)
            dc_str_unref(cString)
            logger?.info(info)
            return info.components(separatedBy: "\n").map { val in
                val.components(separatedBy: "=")
            }
        }
        return []
    }

    func interruptIdle() {
        dc_interrupt_imap_idle(contextPointer)
        dc_interrupt_smtp_idle((contextPointer))
        dc_interrupt_mvbox_idle((contextPointer))
        dc_interrupt_sentbox_idle((contextPointer))
    }

    func openDatabase(dbFile: String) {
        _ = dc_open(contextPointer, dbFile, nil)
    }

    func closeDatabase() {
        dc_close(contextPointer)
    }

    func performImap() {
        dc_perform_imap_jobs(contextPointer)
        dc_perform_imap_fetch(contextPointer)
        dc_perform_imap_idle(contextPointer)
    }

    func performMoveBox() {
        dc_perform_mvbox_jobs(contextPointer)
        dc_perform_mvbox_fetch(contextPointer)
        dc_perform_mvbox_idle(contextPointer)
    }

    func performSmtp() {
        dc_perform_smtp_jobs(contextPointer)
        dc_perform_smtp_idle(contextPointer)
    }

    func performSentbox() {
        dc_perform_sentbox_jobs(contextPointer)
        dc_perform_sentbox_fetch(contextPointer)
        dc_perform_sentbox_idle(contextPointer)
    }

    func setStockTranslation(id: Int32, localizationKey: String) {
        dc_set_stock_translation(contextPointer, UInt32(id), String.localized(localizationKey))
    }

    func getDraft(chatId: Int) -> String? {
        if let draft = dc_get_draft(contextPointer, UInt32(chatId)) {
            if let cString = dc_msg_get_text(draft) {
                let swiftString = String(cString: cString)
                dc_str_unref(cString)
                dc_msg_unref(draft)
                return swiftString
            }
            dc_msg_unref(draft)
            return nil
        }
        return nil
    }

    func setDraft(chatId: Int, draftText: String) {
        let draft = dc_msg_new(contextPointer, DC_MSG_TEXT)
        dc_msg_set_text(draft, draftText.cString(using: .utf8))
        dc_set_draft(contextPointer, UInt32(chatId), draft)

        // cleanup
        dc_msg_unref(draft)
    }

    func getFreshMessages() -> DcArray {
        return DcArray(arrayPointer: dc_get_fresh_msgs(contextPointer))
    }

    func markSeenMessages(messageIds: [UInt32], count: Int = 1) {
        let ptr = UnsafePointer(messageIds)
        dc_markseen_msgs(contextPointer, ptr, Int32(count))
    }

    func getChatMessages(chatId: Int) -> OpaquePointer {
        return dc_get_chat_msgs(contextPointer, UInt32(chatId), 0, 0)
    }
    
    func getMsgInfo(msgId: Int) -> String {
        if let cString = dc_get_msg_info(self.contextPointer, UInt32(msgId)) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        return "ErrGetMsgInfo"
    }

    func deleteMessage(msgId: Int) {
        dc_delete_msgs(contextPointer, [UInt32(msgId)], 1)
    }

    func forwardMessage(with msgId: Int, to chat: Int) {
        dc_forward_msgs(contextPointer, [UInt32(msgId)], 1, UInt32(chat))
    }

    func sendTextInChat(id: Int, message: String) {
        dc_send_text_msg(contextPointer, UInt32(id), message)
    }

    func initiateKeyTransfer() -> String? {
        if let cString = dc_initiate_key_transfer(self.contextPointer) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        return nil
    }

    func continueKeyTransfer(msgId: Int, setupCode: String) -> Bool {
        return dc_continue_key_transfer(self.contextPointer, UInt32(msgId), setupCode) != 0
    }

    func configure() {
        dc_configure(contextPointer)
    }

    func getConfig(_ key: String) -> String? {
        guard let cString = dc_get_config(self.contextPointer, key) else { return nil }
        let value = String(cString: cString)
        dc_str_unref(cString)
        if value.isEmpty {
            return nil
        }
        return value
    }

    func setConfig(_ key: String, _ value: String?) {
        if let v = value {
            dc_set_config(self.contextPointer, key, v)
        } else {
            dc_set_config(self.contextPointer, key, nil)
        }
    }

    func getConfigBool(_ key: String) -> Bool {
        return strToBool(getConfig(key))
    }

    func setConfigBool(_ key: String, _ value: Bool) {
        let vStr = value ? "1" : "0"
        setConfig(key, vStr)
    }

    func getConfigInt(_ key: String) -> Int {
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

    private func setConfigInt(_ key: String, _ value: Int) {
        setConfig(key, String(value))
    }

    func getUnreadMessages(chatId: Int) -> Int {
        return Int(dc_get_fresh_msg_cnt(contextPointer, UInt32(chatId)))
    }

    func emptyServer(flags: Int) {
        dc_empty_server(contextPointer, UInt32(flags))
    }

    func isConfigured() -> Bool {
        return dc_is_configured(contextPointer) != 0
    }

    func getSelfAvatarImage() -> UIImage? {
       guard let fileName = selfavatar else { return nil }
       let path: URL = URL(fileURLWithPath: fileName, isDirectory: false)
       if path.isFileURL {
           do {
               let data = try Data(contentsOf: path)
               return UIImage(data: data)
           } catch {
               logger?.warning("failed to load image: \(fileName), \(error)")
               return nil
           }
       }
       return nil
    }

    func saveChatAvatarImage(chatId: Int, path: String) {
        dc_set_chat_profile_image(contextPointer, UInt32(chatId), path)
    }

    @discardableResult
    func addDeviceMessage(label: String, msg: DcMsg) -> Int {
        return Int(dc_add_device_msg(contextPointer, label.cString(using: .utf8), msg.cptr))
    }

    func updateDeviceChats() {
        dc_update_device_chats(contextPointer)
    }

    func getProviderFromEmail(addr: String) -> DcProvider? {
        guard let dcProviderPointer = dc_provider_new_from_email(contextPointer, addr) else { return nil }
        return DcProvider(dcProviderPointer)
    }

    func imex(what: Int32, directory: String) {
        dc_imex(contextPointer, what, directory, nil)
    }

    func imexHasBackup(filePath: String) -> String? {
        var file: String?
        if let cString = dc_imex_has_backup(contextPointer, filePath) {
            file = String(cString: cString)
            dc_str_unref(cString)
        }
        return file
    }

    func isSendingLocationsToChat(chatId: Int) -> Bool {
        return dc_is_sending_locations_to_chat(contextPointer, UInt32(chatId)) == 1
    }

    func sendLocationsToChat(chatId: Int, seconds: Int) {
        dc_send_locations_to_chat(contextPointer, UInt32(chatId), Int32(seconds))
    }

    func setLocation(latitude: Double, longitude: Double, accuracy: Double) {
        dc_set_location(contextPointer, latitude, longitude, accuracy)
    }

    func searchMessages(chatId: Int = 0, searchText: String) -> [Int] {
        guard let arrayPointer = dc_search_msgs(contextPointer, UInt32(chatId), searchText) else {
            return []
        }
        let messageIds = Utils.copyAndFreeArray(inputArray: arrayPointer)
        return messageIds
    }

    // call dc_maybe_network() from a worker thread.
    func maybeNetwork() {
        dc_maybe_network(contextPointer)
    }

    // also, there is no much worth in adding a separate function or so
    // for each config option - esp. if they are just forwarded to the core
    // and set/get only at one line of code each.
    // this adds a complexity that can be avoided -
    // and makes grep harder as these names are typically named following different guidelines.

    var displayname: String? {
        set { setConfig("displayname", newValue) }
        get { return getConfig("displayname") }
    }

    var selfstatus: String? {
        set { setConfig("selfstatus", newValue) }
        get { return getConfig("selfstatus") }
    }

    var selfavatar: String? {
        set { setConfig("selfavatar", newValue) }
        get { return getConfig("selfavatar") }
    }

    var addr: String? {
        set { setConfig("addr", newValue) }
        get { return getConfig("addr") }
    }

    var mailServer: String? {
        set { setConfig("mail_server", newValue) }
        get { return getConfig("mail_server") }
    }

    var mailUser: String? {
        set { setConfig("mail_user", newValue) }
        get { return getConfig("mail_user") }
    }

    var mailPw: String? {
        set { setConfig("mail_pw", newValue) }
        get { return getConfig("mail_pw") }
    }

    var mailPort: String? {
        set { setConfig("mail_port", newValue) }
        get { return getConfig("mail_port") }
    }

    var sendServer: String? {
        set { setConfig("send_server", newValue) }
        get { return getConfig("send_server") }
    }

    var sendUser: String? {
        set { setConfig("send_user", newValue) }
        get { return getConfig("send_user") }
    }

    var sendPw: String? {
        set { setConfig("send_pw", newValue) }
        get { return getConfig("send_pw") }
    }

    var sendPort: String? {
        set { setConfig("send_port", newValue) }
        get { return getConfig("send_port") }
    }

    var certificateChecks: Int {
        set {
            setConfig("smtp_certificate_checks", "\(newValue)")
            setConfig("imap_certificate_checks", "\(newValue)")
        }
        get {
            if let str = getConfig("imap_certificate_checks") {
                return Int(str) ?? 0
            } else {
                return 0
            }
        }
    }

    private var serverFlags: Int {
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

    func setImapSecurity(imapFlags flags: Int) {
        var sf = serverFlags
        sf = sf & ~0x700 // DC_LP_IMAP_SOCKET_FLAGS
        sf = sf | flags
        serverFlags = sf
    }

    func setSmtpSecurity(smptpFlags flags: Int) {
        var sf = serverFlags
        sf = sf & ~0x70000 // DC_LP_SMTP_SOCKET_FLAGS
        sf = sf | flags
        serverFlags = sf
    }

    func setAuthFlags(flags: Int) {
        var sf = serverFlags
        sf = sf & ~0x6 // DC_LP_AUTH_FLAGS
        sf = sf | flags
        serverFlags = sf
    }

    func getImapSecurity() -> Int {
        var sf = serverFlags
        sf = sf & 0x700 // DC_LP_IMAP_SOCKET_FLAGS
        return sf
    }

    func getSmtpSecurity() -> Int {
        var sf = serverFlags
        sf = sf & 0x70000  // DC_LP_SMTP_SOCKET_FLAGS
        return sf
    }

    func getAuthFlags() -> Int {
        var sf = serverFlags
        sf = sf & 0x6 // DC_LP_AUTH_FLAGS
        return sf
    }

    var e2eeEnabled: Bool {
        set { setConfigBool("e2ee_enabled", newValue) }
        get { return getConfigBool("e2ee_enabled") }
    }

    var mdnsEnabled: Bool {
        set { setConfigBool("mdns_enabled", newValue) }
        get { return getConfigBool("mdns_enabled") }
    }

    var showEmails: Int {
        // one of DC_SHOW_EMAILS_*
        set { setConfigInt("show_emails", newValue) }
        get { return getConfigInt("show_emails") }
    }

    // do not use. use DcContext::isConfigured() instead
    var configured: Bool {
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

    // use DcContext.getChat() instead of calling the constructor directly
    init(id: Int) {
        if let p = dc_get_chat(DcContext.shared.contextPointer, UInt32(id)) {
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
        dc_str_unref(cString)
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

    var isArchived: Bool {
        return Int(dc_chat_get_visibility(chatPointer)) == DC_CHAT_VISIBILITY_ARCHIVED
    }

    var visibility: Int32 {
        return dc_chat_get_visibility(chatPointer)
    }

    var isUnpromoted: Bool {
        return Int(dc_chat_is_unpromoted(chatPointer)) != 0
    }

    var isGroup: Bool {
        let type = Int(dc_chat_get_type(chatPointer))
        return type == DC_CHAT_TYPE_GROUP || type == DC_CHAT_TYPE_VERIFIED_GROUP
    }

    var isSelfTalk: Bool {
        return Int(dc_chat_is_self_talk(chatPointer)) != 0
    }

    var isDeviceTalk: Bool {
        return Int(dc_chat_is_device_talk(chatPointer)) != 0
    }

    var canSend: Bool {
        return Int(dc_chat_can_send(chatPointer)) != 0
    }

    var isVerified: Bool {
        return dc_chat_is_verified(chatPointer) > 0
    }

    var contactIds: [Int] {
        return Utils.copyAndFreeArray(inputArray: dc_get_chat_contacts(DcContext.shared.contextPointer, UInt32(id)))
    }

    lazy var profileImage: UIImage? = { [unowned self] in
        guard let cString = dc_chat_get_profile_image(chatPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        if path.isFileURL {
            do {
                let data = try Data(contentsOf: path)
                let image = UIImage(data: data)
                return image
            } catch {
                DcContext.shared.logger?.warning("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
        }()

    var isSendingLocations: Bool {
        return dc_chat_is_sending_locations(chatPointer) == 1
    }
}

class DcArray {
    private var dcArrayPointer: OpaquePointer?

    init(arrayPointer: OpaquePointer) {
        dcArrayPointer = arrayPointer
    }

    deinit {
        dc_array_unref(dcArrayPointer)
    }

    var count: Int {
       return Int(dc_array_get_cnt(dcArrayPointer))
    }

    ///TODO: add missing methods here
}

class DcMsg: MessageType {
    private var messagePointer: OpaquePointer?

    /**
        viewType: one of
            DC_MSG_TEXT,
            DC_MSG_IMAGE,
            DC_MSG_GIF,
            DC_MSG_STICKER,
            DC_MSG_AUDIO,
            DC_MSG_VOICE,
            DC_MSG_VIDEO,
            DC_MSG_FILE
     */
    init(viewType: Int32) {
        messagePointer = dc_msg_new(DcContext.shared.contextPointer, viewType)
    }

    init(id: Int) {
        messagePointer = dc_get_msg(DcContext.shared.contextPointer, UInt32(id))
    }

    init(type: Int32) {
        messagePointer = dc_msg_new(DcContext.shared.contextPointer, type)
    }

    deinit {
        dc_msg_unref(messagePointer)
    }

    var cptr: OpaquePointer? {
        return messagePointer
    }

    lazy var sender: SenderType = {
        Sender(id: "\(fromContactId)", displayName: fromContact.displayName)
    }()

    lazy var sentDate: Date = {
        Date(timeIntervalSince1970: Double(timestamp))
    }()

    func formattedSentDate() -> String {
        return DateUtils.getExtendedRelativeTimeSpanString(timeStamp: Double(timestamp))
    }

    lazy var kind: MessageKind = {
        if isInfo {
            let text = NSAttributedString(string: self.text ?? "", attributes: [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: DcColors.grayTextColor,
                ])
            return MessageKind.info(text)
        } else if isSetupMessage {
            return MessageKind.text(String.localized("autocrypt_asm_click_body"))
        }

        let text = self.text ?? ""

        if self.viewtype == nil {
            return MessageKind.text(text)
        }

        switch self.viewtype! {
        case .image:
            return createImageMessage(text: text)
        case .video:
            return createVideoMessage(text: text)
        case .voice, .audio:
            return createAudioMessage(text: text)
        default:
            // TODO: custom views for audio, etc
            if let filename = self.filename {
                if Utils.hasAudioSuffix(url: fileURL!) {
                   return createAudioMessage(text: text)
                }
                return createFileMessage(text: text)
            }
            return MessageKind.text(text)
        }
    }()

    internal func createVideoMessage(text: String) -> MessageKind {
        let thumbnail = Utils.generateThumbnailFromVideo(url: fileURL)
        if text.isEmpty {
            return MessageKind.video(Media(url: fileURL, image: thumbnail))
        }
        let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                             NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        return MessageKind.videoText(Media(url: fileURL, image: thumbnail, text: attributedString))
    }

    internal func createImageMessage(text: String) -> MessageKind {
        if text.isEmpty {
            return MessageKind.photo(Media(image: image))
        }
        let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                             NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        return MessageKind.photoText(Media(image: image, text: attributedString))
    }

    internal func createAudioMessage(text: String) -> MessageKind {
        let audioAsset = AVURLAsset(url: fileURL!)
        let seconds = Float(CMTimeGetSeconds(audioAsset.duration))
        if !text.isEmpty {
            let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                                 NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
            return MessageKind.audio(Audio(url: audioAsset.url, duration: seconds, text: attributedString))
        }
        return MessageKind.audio(Audio(url: fileURL!, duration: seconds))
    }

    internal func createFileMessage(text: String) -> MessageKind {
        let fileString = "\(self.filename ?? "???") (\(self.filesize / 1024) kB)"
        let attributedFileString = NSMutableAttributedString(string: fileString,
                                                             attributes: [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 13.0),
                                                                          NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        if !text.isEmpty {
            attributedFileString.append(NSAttributedString(string: "\n\n",
                                                           attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 7.0)]))
            attributedFileString.append(NSAttributedString(string: text,
                                                           attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                        NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor]))
        }
        return MessageKind.fileText(Media(text: attributedFileString))
    }

    var isForwarded: Bool {
        return dc_msg_is_forwarded(messagePointer) != 0
    }

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
        set {
            if let newValue = newValue {
                dc_msg_set_text(messagePointer, newValue.cString(using: .utf8))
            } else {
                dc_msg_set_text(messagePointer, nil)
            }
        }
        get {
            guard let cString = dc_msg_get_text(messagePointer) else { return nil }
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
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
        case DC_MSG_STICKER:
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
                    DcContext.shared.logger?.warning("failed to load image: \(path), \(error)")
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
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    var filemime: String? {
        if let cString = dc_msg_get_filemime(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    var filename: String? {
        if let cString = dc_msg_get_filename(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    func setFile(filepath: String?, mimeType: String?) {
        dc_msg_set_file(messagePointer, filepath, mimeType)
    }

    func setDimension(width: CGFloat, height: CGFloat) {
        dc_msg_set_dimension(messagePointer, Int32(width), Int32(height))
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

    var timestamp: Int64 {
        return Int64(dc_msg_get_timestamp(messagePointer))
    }

    var isInfo: Bool {
        return dc_msg_is_info(messagePointer) == 1
    }

    var isSetupMessage: Bool {
        return dc_msg_is_setupmessage(messagePointer) == 1
    }

    var setupCodeBegin: String {
        guard let cString = dc_msg_get_setupcodebegin(messagePointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    func summary(chars: Int) -> String? {
        guard let cString = dc_msg_get_summarytext(messagePointer, Int32(chars)) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    func summary(chat: DcChat) -> DcLot {
        guard let chatPointer = chat.chatPointer else {
            fatalError()
        }
        guard let dcLotPointer = dc_msg_get_summary(messagePointer, chatPointer) else {
            fatalError()
        }
        return DcLot(dcLotPointer)
    }

    func showPadlock() -> Bool {
        return dc_msg_get_showpadlock(messagePointer) == 1
    }

    func sendInChat(id: Int) {
        dc_send_msg(DcContext.shared.contextPointer, UInt32(id), messagePointer)
    }

    func previousMediaURLs() -> [URL] {
        var urls: [URL] = []
        var prev: Int = Int(dc_get_next_media(DcContext.shared.contextPointer, UInt32(id), -1, Int32(type), 0, 0))
        while prev != 0 {
            let prevMessage = DcMsg(id: prev)
            if let url = prevMessage.fileURL {
                urls.insert(url, at: 0)
            }
            prev = Int(dc_get_next_media(DcContext.shared.contextPointer, UInt32(prevMessage.id), -1, Int32(prevMessage.type), 0, 0))
        }
        return urls
    }

    func nextMediaURLs() -> [URL] {
        var urls: [URL] = []
        var next: Int = Int(dc_get_next_media(DcContext.shared.contextPointer, UInt32(id), 1, Int32(type), 0, 0))
        while next != 0 {
            let nextMessage = DcMsg(id: next)
            if let url = nextMessage.fileURL {
                urls.append(url)
            }
            next = Int(dc_get_next_media(DcContext.shared.contextPointer, UInt32(nextMessage.id), 1, Int32(nextMessage.type), 0, 0))
        }
        return urls
    }
}

class DcContact {
    private var contactPointer: OpaquePointer?

    init(id: Int) {
        contactPointer = dc_get_contact(DcContext.shared.contextPointer, UInt32(id))
    }

    deinit {
        dc_contact_unref(contactPointer)
    }

    var displayName: String {
        guard let cString = dc_contact_get_display_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    var nameNAddr: String {
        guard let cString = dc_contact_get_name_n_addr(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    var name: String {
        guard let cString = dc_contact_get_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    var email: String {
        guard let cString = dc_contact_get_addr(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
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
        dc_str_unref(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        if path.isFileURL {
            do {
                let data = try Data(contentsOf: path)
                return UIImage(data: data)
            } catch {
                DcContext.shared.logger?.warning("failed to load image: \(filename), \(error)")
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
        dc_block_contact(DcContext.shared.contextPointer, UInt32(id), 1)
    }

    func unblock() {
        dc_block_contact(DcContext.shared.contextPointer, UInt32(id), 0)
    }

    func marknoticed() {
        dc_marknoticed_contact(DcContext.shared.contextPointer, UInt32(id))
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
        dc_str_unref(cString)
        return swiftString
    }

    var text1Meaning: Int {
        return Int(dc_lot_get_text1_meaning(dcLotPointer))
    }

    var text2: String? {
        guard let cString = dc_lot_get_text2(dcLotPointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
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

class DcProvider {
    private var dcProviderPointer: OpaquePointer?

    // takes ownership of specified pointer
    init(_ dcProviderPointer: OpaquePointer) {
        self.dcProviderPointer = dcProviderPointer
    }

    deinit {
        dc_provider_unref(dcProviderPointer)
    }

    var status: Int {
        return Int(dc_provider_get_status(dcProviderPointer))
    }

    var beforeLoginHint: String {
        guard let cString = dc_provider_get_before_login_hint(dcProviderPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    var getOverviewPage: String {
        guard let cString = dc_provider_get_overview_page(dcProviderPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }
}

enum ChatType: Int {
    case SINGLE = 100
    case GROUP = 120
    case VERIFIEDGROUP = 130
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
