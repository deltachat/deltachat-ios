import UIKit

/// An object representing a single account
///
/// See [dc_context_t Class Reference](https://c.delta.chat/classdc__context__t.html)
public class DcContext {

    private var encryptedDatabases: [Int: Bool] = [:]

    var contextPointer: OpaquePointer?

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

    public func sendEditRequest(msgId: Int, newText: String) {
        dc_send_edit_request(contextPointer, UInt32(msgId), newText)
    }

    public func sendDeleteRequest(msgIds: [Int]) {
        dc_send_delete_request(contextPointer, msgIds.compactMap { UInt32($0) }, Int32(msgIds.count))
    }

    public func downloadFullMessage(id: Int) {
        dc_download_full_msg(contextPointer, Int32(id))
    }

    public func sendWebxdcStatusUpdate(msgId: Int, payload: String) -> Bool {
        return dc_send_webxdc_status_update(contextPointer, UInt32(msgId), payload, nil) == 1
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
        do {
            try DcAccounts.shared.blockingCall(method: "send_webxdc_realtime_advertisement", params: [id as AnyObject, messageId as AnyObject])
        } catch {
            logger.error(error.localizedDescription)
        }
    }

    public func sendWebxdcRealtimeData(messageId: Int, uint8Array: [UInt8]) {
        do {
            try DcAccounts.shared.blockingCall(method: "send_webxdc_realtime_data", params: [id as AnyObject, messageId as AnyObject, uint8Array as AnyObject])
        } catch {
            logger.error(error.localizedDescription)
        }
    }

    public func leaveWebxdcRealtime(messageId: Int) {
        do {
            try DcAccounts.shared.blockingCall(method: "leave_webxdc_realtime", params: [id as AnyObject, messageId as AnyObject])
        } catch {
            logger.error(error.localizedDescription)
        }
    }

    public func getChatMsgs(chatId: Int, flags: Int32) -> [Int] {
        let start = CFAbsoluteTimeGetCurrent()
        let cMessageIds = dc_get_chat_msgs(contextPointer, UInt32(chatId), UInt32(flags), 0)
        let diff = CFAbsoluteTimeGetCurrent() - start
        logger.info("⏰ getChatMsgs: \(diff) s")

        let ids = DcUtils.copyAndFreeArray(inputArray: cMessageIds)
        return ids
    }

    public func createContact(name: String?, email: String) -> Int {
        return Int(dc_create_contact(contextPointer, name, email))
    }

    public func changeContactName(contactId: Int, name: String) {
        do {
            try DcAccounts.shared.blockingCall(method: "change_contact_name", params: [id as AnyObject, contactId as AnyObject, name as AnyObject])
        } catch {
            logger.error(error.localizedDescription)
        }
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
        return Int(dc_lookup_contact_id_by_addr(contextPointer, address))
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

    public func getChatIdByContactId(_ contactId: Int) -> Int {
        return Int(dc_get_chat_id_by_contact_id(contextPointer, UInt32(contactId)))
    }

    public func getDeviceTalkChat() -> DcChat {
        let deviceTalkChatId = getChatIdByContactId(Int(DC_CONTACT_ID_DEVICE))
        return getChat(chatId: deviceTalkChatId)
    }

    public func getSelfTalkChat() -> DcChat {
        let selfTalkChatId = getChatIdByContactId(Int(DC_CONTACT_ID_SELF))
        return getChat(chatId: selfTalkChatId)
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

    private let getAllMediaCountMax = 500
    public func getAllMediaCount(chatId: Int) -> Int {
        var c = getChatMedia(chatId: chatId, messageType: DC_MSG_IMAGE, messageType2: DC_MSG_GIF, messageType3: DC_MSG_VIDEO).count
        if c < getAllMediaCountMax {
            c += getChatMedia(chatId: chatId, messageType: DC_MSG_AUDIO, messageType2: DC_MSG_VOICE, messageType3: 0).count
        }
        if c < getAllMediaCountMax {
            c += getChatMedia(chatId: chatId, messageType: DC_MSG_FILE, messageType2: DC_MSG_WEBXDC, messageType3: 0).count
        }
        return c
    }

    public func getAllMediaCountString(chatId: Int) -> String {
        let c = getAllMediaCount(chatId: chatId)
        if c == 0 {
            return String.localized("none")
        } else if c >= getAllMediaCountMax {
            return "\(getAllMediaCountMax)+"
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

    public func createBroadcast(name: String) -> Int {
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "create_broadcast", params: [id as AnyObject, name as AnyObject]) {
                return try JSONDecoder().decode(JsonrpcIntResult.self, from: data).result
            }
        } catch {
            logger.error(error.localizedDescription)
        }
        return 0
    }

    public func createGroupChatUnencrypted(name: String) -> Int {
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "create_group_chat_unencrypted", params: [id as AnyObject, name as AnyObject]) {
                return try JSONDecoder().decode(JsonrpcIntResult.self, from: data).result
            }
        } catch {
            logger.error(error.localizedDescription)
        }
        return 0
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

    public func createQRSVG(for payload: String) -> String? {
        guard let cString = dc_create_qr_svg(payload) else { return nil }

        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func getSecurejoinQrSVG(chatId: Int) -> String? {
        if let cString = dc_get_securejoin_qr_svg(self.contextPointer, UInt32(chatId)) {
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        return nil
    }

    public func joinSecurejoin(qrCode: String) -> Int {
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

    public func getFreshMessagesCount() -> Int {
        let arr = dc_get_fresh_msgs(contextPointer)
        let cnt = dc_array_get_cnt(arr)
        dc_array_unref(arr)
        return cnt
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
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "get_message_reactions", params: [id as AnyObject, messageId as AnyObject]) {
                return try JSONDecoder().decode(DcReactionResult.self, from: data).result
            }
        } catch {
            logger.error(error.localizedDescription)
        }
        return nil
    }

    public func sendReaction(messageId: Int, reaction: String?) {
        do {
            if let reaction {
                try DcAccounts.shared.blockingCall(method: "send_reaction", params: [id as AnyObject, messageId as AnyObject, [reaction] as AnyObject])
            } else {
                try DcAccounts.shared.blockingCall(method: "send_reaction", params: [id as AnyObject, messageId as AnyObject, [] as AnyObject])
            }
        } catch {
            logger.error(error.localizedDescription)
        }
    }

    public func makeVCard(contactIds: [Int]) -> Data? {
        do {
            guard let vcardRPCResult = try DcAccounts.shared.blockingCall(method: "make_vcard", params: [id as AnyObject, contactIds as AnyObject]) else { return nil }

            let vcard = try JSONDecoder().decode(DcVCardMakeResult.self, from: vcardRPCResult).result
            return vcard.data(using: .utf8)
        } catch {
            logger.error("cannot make vcard: \(error)")
            return nil
        }
    }

    public func parseVcard(path: String) -> [DcVcardContact]? {
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "parse_vcard", params: [path as AnyObject]) {
                do {
                    return try JSONDecoder().decode(DcVcardContactResult.self, from: data).result
                } catch {
                    logger.error("cannot parse vcard: \(error)")
                }
            }
        } catch {
            logger.error(error.localizedDescription)
        }
        return nil
    }

    public func importVcard(path: String) -> [Int]? {
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "import_vcard", params: [id as AnyObject, path as AnyObject]) {
                do {
                    return try JSONDecoder().decode(DcVcardImportResult.self, from: data).result
                } catch {
                    logger.error("cannot import vcard: \(error)")
                }
            }
        } catch {
            logger.error(error.localizedDescription)
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

    public func forwardMessages(with msgIds: [Int], to chat: Int) {
        dc_forward_msgs(contextPointer, msgIds.compactMap { UInt32($0) }, Int32(msgIds.count), UInt32(chat))
    }

    public func saveMessages(with msgIds: [Int]) {
        dc_save_msgs(contextPointer, msgIds.compactMap { UInt32($0) }, Int32(msgIds.count))
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

    public func listTransports() -> [DcEnteredLoginParam] {
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "list_transports", params: [id as AnyObject]) {
                return try JSONDecoder().decode(DcEnteredLoginParamResult.self, from: data).result
            }
        } catch {
            logger.error(error.localizedDescription)
        }
        return []
    }

    public func addOrUpdateTransport(param: DcEnteredLoginParam) throws -> Bool {
        let res = try DcAccounts.shared.blockingCall(method: "add_or_update_transport", accountId: id, codable: param)
        return res != nil
    }

    public func addTransportFromQr(qrCode: String) throws -> Bool {
        let res = try DcAccounts.shared.blockingCall(method: "add_transport_from_qr", params: [id as AnyObject, qrCode as AnyObject])
        return res != nil
    }

    public func deleteTransport(addr: String) throws {
        try DcAccounts.shared.blockingCall(method: "delete_transport", params: [id as AnyObject, addr as AnyObject])
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
        dc_set_config(self.contextPointer, key, value)
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

    public func isMuted() -> Bool {
        return getConfigBool("is_muted")
    }

    public func setMuted(_ muted: Bool) {
        setConfigBool("is_muted", muted)
    }

    public var isMentionsEnabled: Bool {
        return !getConfigBool("ui.mute_mentions_if_muted")
    }

    public func setMentionsEnabled(_ enabled: Bool) {
        setConfigBool("ui.mute_mentions_if_muted", !enabled)
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

    public var selfstatus: String? {
        get { return getConfig("selfstatus") }
        set { setConfig("selfstatus", newValue) }
    }

    public var selfavatar: String? {
        get { return getConfig("selfavatar") }
        set { setConfig("selfavatar", newValue) }
    }

    public var addr: String? {
        return getConfig("addr")
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

    public var isProxyEnabled: Bool {
        get { return getConfigBool("proxy_enabled") }
        set { setConfigBool("proxy_enabled", newValue) }
    }

    public func getProxies() -> [String] {
        guard let proxyURLStrings = getConfig("proxy_url") else { return [] }

        let proxies = proxyURLStrings.components(separatedBy: "\n")
        return proxies
    }

    public func setProxies(proxyURLs: [String]) {
        let allProxies = proxyURLs.joined(separator: "\n")

        setConfig("proxy_url", allProxies)
    }

    public func placeOutgoingCall(chatId: Int, placeCallInfo: String) -> Int {
        let msgId = dc_place_outgoing_call(contextPointer, UInt32(chatId), placeCallInfo)
        logger.info("☎️ (\(self.id),\(msgId))=dc_place_outgoing_call(\(chatId)")
        return Int(msgId)
    }

    public func acceptIncomingCall(msgId: Int, acceptCallInfo: String) {
        logger.info("☎️ dc_accept_incoming_call(\(self.id),\(msgId))")
        dc_accept_incoming_call(contextPointer, UInt32(msgId), acceptCallInfo)
    }

    public func endCall(msgId: Int) {
        logger.info("☎️ dc_end_call(\(self.id),\(msgId))")
        dc_end_call(contextPointer, UInt32(msgId))
    }

    public func iceServers() -> String {
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "ice_servers", params: [id as AnyObject]) {
                return try JSONDecoder().decode(JsonrpcStringResult.self, from: data).result
            }
        } catch {
            logger.error(error.localizedDescription)
        }
        return "[]"
    }

    public func getStorageUsageReportString() -> String {
        do {
            if let data = try DcAccounts.shared.blockingCall(method: "get_storage_usage_report_string", params: [id as AnyObject]) {
                return try JSONDecoder().decode(JsonrpcStringResult.self, from: data).result
            }
        } catch {
            logger.error(error.localizedDescription)
        }
        return "ErrUsageReport"
    }
}
