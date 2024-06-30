import UIKit

/// An object representing a single account
///
/// See [dc_context_t Class Reference](https://c.delta.chat/classdc__context__t.html)
public class DcContext {

    private var encryptedDatabases: [Int: Bool] = [:]

    var contextPointer: OpaquePointer?
    private var anyWebxdcSeen: Bool = false

    public init(contextPointer: OpaquePointer?) {
        self.contextPointer = contextPointer
    }

    deinit {
        if contextPointer == nil { return } // avoid a warning about a "careless call"
        dc_context_unref(contextPointer)
        contextPointer = nil
    }

    public var id: Int {
        return Int(dc_get_id(contextPointer))
    }

    public var lastErrorString: String {
        guard let cString = dc_get_last_error(contextPointer) else { return "ErrNull" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func open(passphrase: String) -> Bool {
        encryptedDatabases[id] = true
        return dc_context_open(contextPointer, passphrase) == 1
    }

    public func isOpen() -> Bool {
        return dc_context_is_open(contextPointer) == 1
    }

    public func isDatabaseEncrypted() -> Bool {
        return encryptedDatabases[id] ?? false
    }

    public func isAnyDatabaseEncrypted() -> Bool {
        return !encryptedDatabases.isEmpty
    }

    // viewType: one of DC_MSG_*
    public func newMessage(viewType: Int32) -> DcMsg {
        let messagePointer = dc_msg_new(contextPointer, viewType)
        return DcMsg(pointer: messagePointer)
    }

    public func getMessage(id: Int) -> DcMsg {
        let messagePointer = dc_get_msg(contextPointer, UInt32(id))
        return DcMsg(pointer: messagePointer)
    }

    public func sendMessage(chatId: Int, message: DcMsg) {
        dc_send_msg(contextPointer, UInt32(chatId), message.messagePointer)
    }

    public func downloadFullMessage(id: Int) {
        dc_download_full_msg(contextPointer, Int32(id))
    }

    public func sendWebxdcStatusUpdate(msgId: Int, payload: String, description: String) -> Bool {
        return dc_send_webxdc_status_update(contextPointer, UInt32(msgId), payload, description) == 1
    }

    public func getWebxdcStatusUpdates(msgId: Int, lastKnownSerial: Int) -> String {
        guard let cString = dc_get_webxdc_status_updates(contextPointer, UInt32(msgId), UInt32(lastKnownSerial)) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func setWebxdcIntegration(filepath: String?) {
        dc_set_webxdc_integration(contextPointer, filepath)
    }

    public func initWebxdcIntegration(for chatId: Int) -> Int {
        return Int(dc_init_webxdc_integration(contextPointer, UInt32(chatId)))
    }

    public func sendWebxdcRealtimeAdvertisement(messageId: Int) {
        DcAccounts.shared.blockingCall(method: "send_webxdc_realtime_advertisement", params: [id as AnyObject, messageId as AnyObject])
    }

    public func sendWebxdcRealtimeData(messageId: Int, uint8Array: [UInt8]) {
        DcAccounts.shared.blockingCall(method: "send_webxdc_realtime_data", params: [id as AnyObject, messageId as AnyObject, uint8Array as AnyObject])
    }

    public func leaveWebxdcRealtime(messageId: Int) {
        DcAccounts.shared.blockingCall(method: "leave_webxdc_realtime", params: [id as AnyObject, messageId as AnyObject])
    }

    public func sendVideoChatInvitation(chatId: Int) -> Int {
        return Int(dc_send_videochat_invitation(contextPointer, UInt32(chatId)))
    }

    public func getChatMsgs(chatId: Int) -> [Int] {
        let start = CFAbsoluteTimeGetCurrent()
        let cMessageIds = dc_get_chat_msgs(contextPointer, UInt32(chatId), UInt32(DC_GCM_ADDDAYMARKER), 0)
        let diff = CFAbsoluteTimeGetCurrent() - start
        logger.info("⏰ getChatMsgs: \(diff) s")

        let ids = DcUtils.copyAndFreeArray(inputArray: cMessageIds)
        return ids
    }

    public func createContact(name: String?, email: String) -> Int {
        return Int(dc_create_contact(contextPointer, name, email))
    }

    public func deleteContact(contactId: Int) -> Bool {
        return dc_delete_contact(self.contextPointer, UInt32(contactId)) == 1
    }

    public func getContacts(flags: Int32, queryString: String? = nil) -> [Int] {
        let start = CFAbsoluteTimeGetCurrent()
        let cContacts = dc_get_contacts(contextPointer, UInt32(flags), queryString)
        let diff = CFAbsoluteTimeGetCurrent() - start
        logger.info("⏰ getContacts: \(diff) s")
        return DcUtils.copyAndFreeArray(inputArray: cContacts)
    }

    public func getContact(id: Int) -> DcContact {
        let contactPointer = dc_get_contact(contextPointer, UInt32(id))
        return DcContact(contactPointer: contactPointer)
    }

    public func blockContact(id: Int) {
        dc_block_contact(contextPointer, UInt32(id), 1)
    }

    public func unblockContact(id: Int) {
        dc_block_contact(contextPointer, UInt32(id), 0)
    }

    public func getBlockedContacts() -> [Int] {
        let cBlockedContacts = dc_get_blocked_contacts(contextPointer)
        return DcUtils.copyAndFreeArray(inputArray: cBlockedContacts)
    }

    public func addContacts(contactString: String) {
        dc_add_address_book(contextPointer, contactString)
    }

    public func lookupContactIdByAddress(_ address: String) -> Int {
        return Int(dc_lookup_contact_id_by_addr(contextPointer, addr))
    }

    public func acceptChat(chatId: Int) {
        dc_accept_chat(contextPointer, UInt32(chatId))
    }

    public func blockChat(chatId: Int) {
        dc_block_chat(contextPointer, UInt32(chatId))
    }

    public func getChat(chatId: Int) -> DcChat {
        let chatPointer = dc_get_chat(contextPointer, UInt32(chatId))
        return DcChat(chatPointer: chatPointer)
    }

    public func getChatIdByContactId(contactId: Int) -> Int {
        return Int(dc_get_chat_id_by_contact_id(contextPointer, UInt32(contactId)))
    }

    public func getChatIdByContactIdOld(_ contactId: Int) -> Int? {
        // deprecated function, use getChatIdByContactId() and check for != 0 as for all other places IDs are used
        let chatId = dc_get_chat_id_by_contact_id(contextPointer, UInt32(contactId))
        if chatId == 0 {
            return nil
        } else {
            return Int(chatId)
        }
    }

    public func getChatlist(flags: Int32, queryString: String?, queryId: Int) -> DcChatlist {
        let start = CFAbsoluteTimeGetCurrent()
        let chatlistPointer = dc_get_chatlist(contextPointer, flags, queryString, UInt32(queryId))
        let chatlist = DcChatlist(chatListPointer: chatlistPointer)
        let diff = CFAbsoluteTimeGetCurrent() - start
        logger.info("⏰ getChatlist: \(diff) s")
        return chatlist
    }

    public func sendMsgSync(chatId: Int, msg: DcMsg) {
        dc_send_msg_sync(contextPointer, UInt32(chatId), msg.messagePointer)
    }

    public func getChatMedia(chatId: Int, messageType: Int32, messageType2: Int32, messageType3: Int32) -> [Int] {
        guard let messagesPointer = dc_get_chat_media(contextPointer, UInt32(chatId), messageType, messageType2, messageType3) else {
            return []
        }

        let messageIds: [Int] =  DcUtils.copyAndFreeArray(inputArray: messagesPointer)
        return messageIds
    }

    public func hasWebxdc(chatId: Int) -> Bool {
        if !anyWebxdcSeen {
            anyWebxdcSeen = !getChatMedia(chatId: chatId, messageType: DC_MSG_WEBXDC, messageType2: 0, messageType3: 0).isEmpty
        }
        return anyWebxdcSeen
    }

    public func getAllMediaCount(chatId: Int) -> String {
        let max = 500
        var c = getChatMedia(chatId: chatId, messageType: DC_MSG_IMAGE, messageType2: DC_MSG_GIF, messageType3: DC_MSG_VIDEO).count
        if c < max {
            c += getChatMedia(chatId: chatId, messageType: DC_MSG_AUDIO, messageType2: DC_MSG_VOICE, messageType3: 0).count
        }
        if c < max {
            c += getChatMedia(chatId: chatId, messageType: DC_MSG_FILE, messageType2: DC_MSG_WEBXDC, messageType3: 0).count
        }
        if c == 0 {
            return String.localized("none")
        } else if c >= max {
            return "\(max)+"
        } else {
            return "\(c)"
        }
    }

    @discardableResult
    public func createChatByContactId(contactId: Int) -> Int {
        return Int(dc_create_chat_by_contact_id(contextPointer, UInt32(contactId)))
    }

    public func createGroupChat(verified: Bool, name: String) -> Int {
        return Int(dc_create_group_chat(contextPointer, verified ? 1 : 0, name))
    }

    public func createBroadcastList() -> Int {
        return Int(dc_create_broadcast_list(contextPointer))
    }

    public func addContactToChat(chatId: Int, contactId: Int) -> Bool {
        return dc_add_contact_to_chat(contextPointer, UInt32(chatId), UInt32(contactId)) == 1
    }

    public func removeContactFromChat(chatId: Int, contactId: Int) -> Bool {
        return dc_remove_contact_from_chat(contextPointer, UInt32(chatId), UInt32(contactId)) == 1
    }

    public func setChatName(chatId: Int, name: String) -> Bool {
        return dc_set_chat_name(contextPointer, UInt32(chatId), name) == 1
    }

    public func deleteChat(chatId: Int) {
        dc_delete_chat(contextPointer, UInt32(chatId))
    }

    public func archiveChat(chatId: Int, archive: Bool) {
        dc_set_chat_visibility(contextPointer, UInt32(chatId), Int32(archive ? DC_CHAT_VISIBILITY_ARCHIVED : DC_CHAT_VISIBILITY_NORMAL))
    }

    public func setChatVisibility(chatId: Int, visibility: Int32) {
        dc_set_chat_visibility(contextPointer, UInt32(chatId), visibility)
    }

    public func marknoticedChat(chatId: Int) {
        dc_marknoticed_chat(self.contextPointer, UInt32(chatId))
    }

    public func getSecurejoinQr(chatId: Int) -> String? {
        if let cString = dc_get_securejoin_qr(self.contextPointer, UInt32(chatId)) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        return nil
    }

    public static func mayBeValidAddr(email: String) -> Bool {
        return dc_may_be_valid_addr(email) != 0
    }

    public func getSecurejoinQrSVG(chatId: Int) -> String? {
        if let cString = dc_get_securejoin_qr_svg(self.contextPointer, UInt32(chatId)) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        return nil
    }

    public func joinSecurejoin (qrCode: String) -> Int {
        return Int(dc_join_securejoin(contextPointer, qrCode))
    }

    public func checkQR(qrCode: String) -> DcLot {
        return DcLot(dc_check_qr(contextPointer, qrCode))
    }

    public func setConfigFromQR(qrCode: String) -> Bool {
        return dc_set_config_from_qr(contextPointer, qrCode) != 0
    }

    public func receiveBackup(qrCode: String) -> Bool {
        return dc_receive_backup(contextPointer, qrCode) != 0
    }

    public func stopOngoingProcess() {
        dc_stop_ongoing_process(contextPointer)
    }

    public func getInfo() -> String {
        if let cString = dc_get_info(contextPointer) {
            let info = String(cString: cString)
            dc_str_unref(cString)
            return info
        }
        return "ErrGetInfo"
    }

    public func getPushState() -> Int32 {
        return dc_get_push_state(contextPointer)
    }

    public func getContactEncrInfo(contactId: Int) -> String {
        if let cString = dc_get_contact_encrinfo(contextPointer, UInt32(contactId)) {
            let switftString = String(cString: cString)
            dc_str_unref(cString)
            return switftString
        }
        return "ErrGetContactEncrInfo"
    }

    public func getConnectivity() -> Int32 {
        return dc_get_connectivity(contextPointer)
    }

    public func getConnectivityHtml() -> String {
        guard let cString = dc_get_connectivity_html(contextPointer) else { return ""}
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func setStockTranslation(id: Int32, localizationKey: String) {
        dc_set_stock_translation(contextPointer, UInt32(id), String.localized(localizationKey))
    }

    public func getDraft(chatId: Int) -> DcMsg? {
        if let draft = dc_get_draft(contextPointer, UInt32(chatId)) {
            return DcMsg(pointer: draft)
        }
        return nil
    }

    public func setDraft(chatId: Int, message: DcMsg?) {
        dc_set_draft(contextPointer, UInt32(chatId), message?.messagePointer)
    }

    public func getFreshMessages() -> DcArray {
        return DcArray(arrayPointer: dc_get_fresh_msgs(contextPointer))
    }

    public func markSeenMessages(messageIds: [UInt32]) {
        messageIds.withUnsafeBufferPointer { ptr in
            dc_markseen_msgs(contextPointer, ptr.baseAddress, Int32(ptr.count))
        }
    }

    public func getMsgInfo(msgId: Int) -> String {
        if let cString = dc_get_msg_info(self.contextPointer, UInt32(msgId)) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        return "ErrGetMsgInfo"
    }

    public func getMsgHtml(msgId: Int) -> String {
        guard let cString = dc_get_msg_html(self.contextPointer, UInt32(msgId)) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func getMessageReactions(messageId: Int) -> DcReactions? {
        if let data = DcAccounts.shared.blockingCall(method: "get_message_reactions", params: [id as AnyObject, messageId as AnyObject]) {
            return try? JSONDecoder().decode(DcReactionResult.self, from: data).result
        }
        return nil
    }

    public func sendReaction(messageId: Int, reaction: String?) {
        if let reaction {
            DcAccounts.shared.blockingCall(method: "send_reaction", params: [id as AnyObject, messageId as AnyObject, [reaction] as AnyObject])
        } else {
            DcAccounts.shared.blockingCall(method: "send_reaction", params: [id as AnyObject, messageId as AnyObject, [] as AnyObject])
        }
    }

    public func makeVCard(contactIds: [Int]) -> Data? {
        guard let vcardRPCResult = DcAccounts.shared.blockingCall(method: "make_vcard", params: [id as AnyObject, contactIds as AnyObject]) else { return nil }

        do {
            let vcard = try JSONDecoder().decode(DcVCardMakeResult.self, from: vcardRPCResult).result
            return vcard.data(using: .utf8)
        } catch {
            logger.error("cannot make vcard: \(error)")
            return nil
        }
    }

    public func parseVcard(path: String) -> [DcVcardContact]? {
        if let data = DcAccounts.shared.blockingCall(method: "parse_vcard", params: [path as AnyObject]) {
            do {
                return try JSONDecoder().decode(DcVcardContactResult.self, from: data).result
            } catch {
                logger.error("cannot parse vcard: \(error)")
            }
        }
        return nil
    }

    public func importVcard(path: String) -> [Int]? {
        if let data = DcAccounts.shared.blockingCall(method: "import_vcard", params: [id as AnyObject, path as AnyObject]) {
            do {
                return try JSONDecoder().decode(DcVcardImportResult.self, from: data).result
            } catch {
                logger.error("cannot import vcard: \(error)")
            }
        }
        return nil
    }


    public func deleteMessage(msgId: Int) {
        dc_delete_msgs(contextPointer, [UInt32(msgId)], 1)
    }

    public func deleteMessages(msgIds: [Int]) {
        dc_delete_msgs(contextPointer, msgIds.compactMap { UInt32($0) }, Int32(msgIds.count))
    }

    public func resendMessages(msgIds: [Int]) {
        dc_resend_msgs(contextPointer, msgIds.compactMap { UInt32($0) }, Int32(msgIds.count))
    }

    public func forwardMessage(with msgId: Int, to chat: Int) {
        dc_forward_msgs(contextPointer, [UInt32(msgId)], 1, UInt32(chat))
    }

    public func forwardMessages(with msgIds: [Int], to chat: Int) {
        dc_forward_msgs(contextPointer, msgIds.compactMap { UInt32($0) }, Int32(msgIds.count), UInt32(chat))
    }

    public func sendTextInChat(id: Int, message: String) {
        dc_send_text_msg(contextPointer, UInt32(id), message)
    }

    public func initiateKeyTransfer() -> String? {
        if let cString = dc_initiate_key_transfer(self.contextPointer) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        return nil
    }

    public func continueKeyTransfer(msgId: Int, setupCode: String) -> Bool {
        return dc_continue_key_transfer(self.contextPointer, UInt32(msgId), setupCode) != 0
    }

    public func configure() {
        dc_configure(contextPointer)
    }

    public func setChatMuteDuration(chatId: Int, duration: Int) {
        dc_set_chat_mute_duration(self.contextPointer, UInt32(chatId), Int64(duration))
    }

    public func setChatEphemeralTimer(chatId: Int, duration: Int) {
        dc_set_chat_ephemeral_timer(self.contextPointer, UInt32(chatId), UInt32(duration))
    }

    public func getChatEphemeralTimer(chatId: Int) -> Int {
        return Int(dc_get_chat_ephemeral_timer(self.contextPointer, UInt32(chatId)))
    }

    public func getConfig(_ key: String) -> String? {
        guard let cString = dc_get_config(self.contextPointer, key) else { return nil }
        let value = String(cString: cString)
        dc_str_unref(cString)
        if value.isEmpty {
            return nil
        }
        return value
    }

    public func setConfig(_ key: String, _ value: String?) {
        if let v = value {
            dc_set_config(self.contextPointer, key, v)
        } else {
            dc_set_config(self.contextPointer, key, nil)
        }
    }

    public func getConfigBool(_ key: String) -> Bool {
        return getConfig(key).numericBoolValue
    }

    public func setConfigBool(_ key: String, _ value: Bool) {
        let vStr = value ? "1" : "0"
        setConfig(key, vStr)
    }

    public func getConfigInt(_ key: String) -> Int {
        if let str = getConfig(key) {
            return Int(str) ?? 0
        }
        return 0
    }

    public func setConfigInt(_ key: String, _ value: Int) {
        setConfig(key, String(value))
    }

    public func getUnreadMessages(chatId: Int) -> Int {
        return Int(dc_get_fresh_msg_cnt(contextPointer, UInt32(chatId)))
    }

    public func estimateDeletionCnt(fromServer: Bool, timeout: Int) -> Int {
        return Int(dc_estimate_deletion_cnt(contextPointer, fromServer ? 1 : 0, Int64(timeout)))
    }

    public func isConfigured() -> Bool {
        return dc_is_configured(contextPointer) != 0
    }

    public func getSelfAvatarImage() -> UIImage? {
       guard let fileName = selfavatar else { return nil }
       let path: URL = URL(fileURLWithPath: fileName, isDirectory: false)
       if path.isFileURL {
           do {
               let data = try Data(contentsOf: path)
               return UIImage(data: data)
           } catch {
               logger.warning("failed to load image: \(fileName), \(error)")
               return nil
           }
       }
       return nil
    }

    public func setChatProfileImage(chatId: Int, path: String?) {
        dc_set_chat_profile_image(contextPointer, UInt32(chatId), path)
    }

    public func wasDeviceMsgEverAdded(label: String) -> Bool {
        return dc_was_device_msg_ever_added(contextPointer, label) != 0
    }

    @discardableResult
    public func addDeviceMessage(label: String?, msg: DcMsg?) -> Int {
        return Int(dc_add_device_msg(contextPointer, label, msg?.cptr ?? nil))
    }

    public func getProviderFromEmailWithDns(addr: String) -> DcProvider? {
        guard let dcProviderPointer = dc_provider_new_from_email_with_dns(contextPointer, addr) else { return nil }
        return DcProvider(dcProviderPointer)
    }

    public func imex(what: Int32, directory: String, passphrase: String? = nil) {
        dc_imex(contextPointer, what, directory, passphrase)
    }

    public func isSendingLocationsToChat(chatId: Int) -> Bool {
        return dc_is_sending_locations_to_chat(contextPointer, UInt32(chatId)) == 1
    }

    public func sendLocationsToChat(chatId: Int, seconds: Int) {
        dc_send_locations_to_chat(contextPointer, UInt32(chatId), Int32(seconds))
    }

    public func setLocation(latitude: Double, longitude: Double, accuracy: Double) {
        dc_set_location(contextPointer, latitude, longitude, accuracy)
    }

    public func searchMessages(chatId: Int = 0, searchText: String) -> [Int] {
        let start = CFAbsoluteTimeGetCurrent()
        guard let arrayPointer = dc_search_msgs(contextPointer, UInt32(chatId), searchText) else {
            return []
        }
        let messageIds = DcUtils.copyAndFreeArray(inputArray: arrayPointer)
        let diff = CFAbsoluteTimeGetCurrent() - start
        logger.info("⏰ searchMessages: \(diff) s")
        return messageIds
    }

    // also, there is no much worth in adding a separate function or so
    // for each config option - esp. if they are just forwarded to the core
    // and set/get only at one line of code each.
    // this adds a complexity that can be avoided -
    // and makes grep harder as these names are typically named following different guidelines.

    public var displayname: String? {
        get { return getConfig("displayname") }
        set { setConfig("displayname", newValue) }
    }

    public var displaynameAndAddr: String {
        var ret = addr ?? ""
        if let displayname = displayname {
            ret = "\(displayname) (\(ret))"
        }
        ret += isConfigured() ? "" : " (not configured)"
        return ret.trimmingCharacters(in: .whitespaces)
    }

    public var selfstatus: String? {
        get { return getConfig("selfstatus") }
        set { setConfig("selfstatus", newValue) }
    }

    public var selfavatar: String? {
        get { return getConfig("selfavatar") }
        set { setConfig("selfavatar", newValue) }
    }

    public var addr: String? {
        get { return getConfig("addr") }
        set { setConfig("addr", newValue) }
    }

    public var mailServer: String? {
        get { return getConfig("mail_server") }
        set { setConfig("mail_server", newValue) }
    }

    public var mailUser: String? {
        get { return getConfig("mail_user") }
        set { setConfig("mail_user", newValue) }
    }

    public var mailPw: String? {
        get { return getConfig("mail_pw") }
        set { setConfig("mail_pw", newValue) }
    }

    public var mailPort: String? {
        get { return getConfig("mail_port") }
        set { setConfig("mail_port", newValue) }
    }

    public var sendServer: String? {
        get { return getConfig("send_server") }
        set { setConfig("send_server", newValue) }
    }

    public var sendUser: String? {
        get { return getConfig("send_user") }
        set { setConfig("send_user", newValue) }
    }

    public var sendPw: String? {
        get { return getConfig("send_pw") }
        set { setConfig("send_pw", newValue) }
    }

    public var sendPort: String? {
        get { return getConfig("send_port") }
        set { setConfig("send_port", newValue) }
    }

    public var certificateChecks: Int {
        get {
            if let str = getConfig("imap_certificate_checks") {
                return Int(str) ?? 0
            } else {
                return 0
            }
        }
        set {
            setConfig("smtp_certificate_checks", "\(newValue)")
            setConfig("imap_certificate_checks", "\(newValue)")
        }
    }

    private var serverFlags: Int {
        // IMAP-/SMTP-flags as a combination of DC_LP flags
        get {
            if let str = getConfig("server_flags") {
                return Int(str) ?? 0
            } else {
                return 0
            }
        }
        set {
            setConfig("server_flags", "\(newValue)")
        }
    }

    public func setAuthFlags(flags: Int) {
        var sf = serverFlags
        sf = sf & ~0x6 // DC_LP_AUTH_FLAGS
        sf = sf | flags
        serverFlags = sf
    }

    public func getAuthFlags() -> Int {
        var sf = serverFlags
        sf = sf & 0x6 // DC_LP_AUTH_FLAGS
        return sf
    }

    public var e2eeEnabled: Bool {
        get { return getConfigBool("e2ee_enabled") }
        set { setConfigBool("e2ee_enabled", newValue) }
    }

    public var mdnsEnabled: Bool {
        get { return getConfigBool("mdns_enabled") }
        set { setConfigBool("mdns_enabled", newValue) }
    }

    public var showEmails: Int {
        // one of DC_SHOW_EMAILS_*
        get { return getConfigInt("show_emails") }
        set { setConfigInt("show_emails", newValue) }
    }

    public var isChatmail: Bool {
        return getConfigInt("is_chatmail") == 1
    }
}
