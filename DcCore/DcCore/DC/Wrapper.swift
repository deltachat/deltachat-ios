import Foundation
import UIKit
import AVFoundation

public class DcAccounts {

    /// The application group identifier defines a group of apps or extensions that have access to a shared container.
    /// The ID is created in the apple developer portal and can be changed there.
    let applicationGroupIdentifier = "group.chat.delta.ios"
    var accountsPointer: OpaquePointer?
    public var logger: Logger?
    public var fetchSemaphore: DispatchSemaphore?

    public init() {
    }

    deinit {
        if accountsPointer == nil { return }
        dc_accounts_unref(accountsPointer)
        accountsPointer = nil
    }

    public func migrate(dbLocation: String) -> Int {
        return Int(dc_accounts_migrate_account(accountsPointer, dbLocation))
    }

    public func addClosedAccount() -> Int {
        return Int(dc_accounts_add_closed_account(accountsPointer))
    }

    public func add() -> Int {
        return Int(dc_accounts_add_account(accountsPointer))
    }

    public func get(id: Int) -> DcContext {
        let contextPointer = dc_accounts_get_account(accountsPointer, UInt32(id))
        return DcContext(contextPointer: contextPointer, logger: logger)
    }

    public func getAll() -> [Int] {
        let cAccounts = dc_accounts_get_all(accountsPointer)
        return DcUtils.copyAndFreeArray(inputArray: cAccounts)
    }

    public func getSelected() -> DcContext {
        let cPtr = dc_accounts_get_selected_account(accountsPointer)
        return DcContext(contextPointer: cPtr, logger: logger)
    }

    // call maybeNetwork() from a worker thread.
    public func maybeNetwork() {
        dc_accounts_maybe_network(accountsPointer)
    }

    public func maybeNetworkLost() {
        dc_accounts_maybe_network_lost(accountsPointer)
    }

    public func isAllWorkDone() -> Bool {
        return dc_accounts_all_work_done(accountsPointer) != 0
    }

    public func startIo() {
        dc_accounts_start_io(accountsPointer)
    }

    public func stopIo() {
        dc_accounts_stop_io(accountsPointer)
    }

    public func select(id: Int) -> Bool {
        return dc_accounts_select_account(accountsPointer, UInt32(id)) == 1
    }

    public func remove(id: Int) -> Bool {
        return dc_accounts_remove_account(accountsPointer, UInt32(id)) == 1
    }

    public func getEventEmitter() -> DcEventEmitter {
        let eventEmitterPointer = dc_accounts_get_event_emitter(accountsPointer)
        return DcEventEmitter(eventEmitterPointer: eventEmitterPointer)
    }

    public func openDatabase() {
        var version = ""
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            version += " " + appVersion
        }

        if var sharedDbLocation = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: applicationGroupIdentifier) {
            sharedDbLocation.appendPathComponent("accounts", isDirectory: true)
            accountsPointer = dc_accounts_new("iOS\(version)", sharedDbLocation.path)
        }
    }

    public func closeDatabase() {
        dc_accounts_unref(accountsPointer)
        accountsPointer = nil
    }
}

public class DcContext {

    public var logger: Logger?
    var contextPointer: OpaquePointer?
    public var lastWarningString: String = "" // temporary thing to get a grip on some weird errors
    public var maxConfigureProgress: Int = 0 // temporary thing to get a grip on some weird errors

    public init(contextPointer: OpaquePointer?, logger: Logger?) {
        self.contextPointer = contextPointer
        self.logger = logger
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

    // The passphrase can be ommited if the account db is not encrypted
    public func open(passphrase: String? = nil) -> Bool {
        dc_context_open(contextPointer, passphrase) == 1
    }

    public func isOpen() -> Bool {
        return dc_context_is_open(contextPointer) == 1
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

    public func sendVideoChatInvitation(chatId: Int) -> Int {
        return Int(dc_send_videochat_invitation(contextPointer, UInt32(chatId)))
    }

    public func getChatMsgs(chatId: Int) -> [Int] {
        let start = CFAbsoluteTimeGetCurrent()
        let cMessageIds = dc_get_chat_msgs(contextPointer, UInt32(chatId), UInt32(DC_GCM_ADDDAYMARKER), 0)
        let diff = CFAbsoluteTimeGetCurrent() - start
        logger?.info("⏰ getChatMsgs: \(diff) s")

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
        logger?.info("⏰ getContacts: \(diff) s")
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
        logger?.info("⏰ getChatlist: \(diff) s")
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
        return !getChatMedia(chatId: chatId, messageType: DC_MSG_WEBXDC, messageType2: 0, messageType3: 0).isEmpty
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
        maxConfigureProgress = 0
        lastWarningString = ""
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
        return strToBool(getConfig(key))
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
               logger?.warning("failed to load image: \(fileName), \(error)")
               return nil
           }
       }
       return nil
    }

    public func setChatProfileImage(chatId: Int, path: String?) {
        dc_set_chat_profile_image(contextPointer, UInt32(chatId), path)
    }

    @discardableResult
    public func addDeviceMessage(label: String?, msg: DcMsg) -> Int {
        return Int(dc_add_device_msg(contextPointer, label, msg.cptr))
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
        logger?.info("⏰ searchMessages: \(diff) s")
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
}


public class DcEventEmitter {
    private var eventEmitterPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(eventEmitterPointer: OpaquePointer?) {
        self.eventEmitterPointer = eventEmitterPointer
    }

    public func getNextEvent() -> DcEvent? {
        guard let eventPointer = dc_get_next_event(eventEmitterPointer) else { return nil }
        return DcEvent(eventPointer: eventPointer)
    }

    deinit {
        dc_event_emitter_unref(eventEmitterPointer)
    }
}

public class DcEvent {
    private var eventPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(eventPointer: OpaquePointer?) {
        self.eventPointer = eventPointer
    }

    deinit {
        dc_event_unref(eventPointer)
    }

    public var accountId: Int {
        return Int(dc_event_get_account_id(eventPointer))
    }

    public var id: Int32 {
        return Int32(dc_event_get_id(eventPointer))
    }

    public var data1Int: Int {
        return Int(dc_event_get_data1_int(eventPointer))
    }

    public var data2Int: Int {
        return Int(dc_event_get_data2_int(eventPointer))
    }

    public var data2String: String {
        guard let cString = dc_event_get_data2_str(eventPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }
}

public class DcChatlist {
    private var chatListPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(chatListPointer: OpaquePointer?) {
        self.chatListPointer = chatListPointer
    }

    deinit {
        dc_chatlist_unref(chatListPointer)
    }

    public var length: Int {
        return dc_chatlist_get_cnt(chatListPointer)
    }

    public func getChatId(index: Int) -> Int {
        return Int(dc_chatlist_get_chat_id(chatListPointer, index))
    }

    public func getMsgId(index: Int) -> Int {
        return Int(dc_chatlist_get_msg_id(chatListPointer, index))
    }

    public func getSummary(index: Int) -> DcLot {
        let lotPointer = dc_chatlist_get_summary(self.chatListPointer, index, nil)
        return DcLot(lotPointer)
    }
}

public class DcChat {
    var chatPointer: OpaquePointer?

    // use DcContext.getChat() instead of calling the constructor directly
    public init(chatPointer: OpaquePointer?) {
        self.chatPointer = chatPointer
    }

    deinit {
        dc_chat_unref(chatPointer)
    }

    public var id: Int {
        return Int(dc_chat_get_id(chatPointer))
    }

    public var isValid: Bool {
        return self.chatPointer != nil
    }

    public var name: String {
        guard let cString = dc_chat_get_name(chatPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var color: UIColor {
        return UIColor(netHex: Int(dc_chat_get_color(chatPointer)))
    }

    public var isArchived: Bool {
        return Int(dc_chat_get_visibility(chatPointer)) == DC_CHAT_VISIBILITY_ARCHIVED
    }

    public var visibility: Int32 {
        return dc_chat_get_visibility(chatPointer)
    }

    public var isUnpromoted: Bool {
        return Int(dc_chat_is_unpromoted(chatPointer)) != 0
    }

    public var isGroup: Bool {
        // isMultiUser() might fit better,
        // however, would result in lots of code changes, so we leave this as is for now.
        let type = Int(dc_chat_get_type(chatPointer))
        return type == DC_CHAT_TYPE_GROUP || type == DC_CHAT_TYPE_MAILINGLIST || type == DC_CHAT_TYPE_BROADCAST
    }

    public var isMailinglist: Bool {
        return Int(dc_chat_get_type(chatPointer)) == DC_CHAT_TYPE_MAILINGLIST
    }

    public var isBroadcast: Bool {
        return Int(dc_chat_get_type(chatPointer)) == DC_CHAT_TYPE_BROADCAST
    }

    public var isSelfTalk: Bool {
        return Int(dc_chat_is_self_talk(chatPointer)) != 0
    }

    public var isDeviceTalk: Bool {
        return Int(dc_chat_is_device_talk(chatPointer)) != 0
    }

    public var isContactRequest: Bool {
        return Int(dc_chat_is_contact_request(chatPointer)) != 0
    }

    public var canSend: Bool {
        return Int(dc_chat_can_send(chatPointer)) != 0
    }

    public var isProtected: Bool {
        return dc_chat_is_protected(chatPointer) != 0
    }

    public var isMuted: Bool {
        return dc_chat_is_muted(chatPointer) != 0
    }

    public func getContactIds(_ dcContext: DcContext) -> [Int] {
        return DcUtils.copyAndFreeArray(inputArray: dc_get_chat_contacts(dcContext.contextPointer, UInt32(id)))
    }

    public func getMailinglistAddr() -> String {
        guard let cString = dc_chat_get_mailinglist_addr(chatPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public lazy var profileImage: UIImage? = {
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
                print("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
    }()

    public var profileImageURL: URL? {
        guard let cString = dc_chat_get_profile_image(chatPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        return path
    }

    public var isSendingLocations: Bool {
        return dc_chat_is_sending_locations(chatPointer) == 1
    }
}

public class DcArray {
    private var dcArrayPointer: OpaquePointer?

    public init(arrayPointer: OpaquePointer) {
        dcArrayPointer = arrayPointer
    }

    deinit {
        dc_array_unref(dcArrayPointer)
    }

    public var count: Int {
       return Int(dc_array_get_cnt(dcArrayPointer))
    }
}

public class DcMsg {
    var messagePointer: OpaquePointer?

    init(pointer: OpaquePointer?) {
        messagePointer = pointer
    }

    deinit {
        dc_msg_unref(messagePointer)
    }

    public var cptr: OpaquePointer? {
        return messagePointer
    }

    public lazy var sentDate: Date = {
        Date(timeIntervalSince1970: Double(timestamp))
    }()

    public func formattedSentDate() -> String {
        return DateUtils.getExtendedRelativeTimeSpanString(timeStamp: Double(timestamp))
    }

    public var isForwarded: Bool {
        return dc_msg_is_forwarded(messagePointer) != 0
    }

    public var messageId: String {
        return "\(id)"
    }

    public var id: Int {
        return Int(dc_msg_get_id(messagePointer))
    }


    public var fromContactId: Int {
        return Int(dc_msg_get_from_id(messagePointer))
    }

    public var isFromCurrentSender: Bool {
        return fromContactId == DC_CONTACT_ID_SELF
    }

    public var chatId: Int {
        return Int(dc_msg_get_chat_id(messagePointer))
    }

    public var overrideSenderName: String? {
        guard let cString = dc_msg_get_override_sender_name(messagePointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func getSenderName(_ dcContact: DcContact, markOverride: Bool = false) -> String {
        if let overrideName = overrideSenderName {
            return (markOverride ? "~" : "") + overrideName
        } else {
            return dcContact.displayName
        }
    }

    public var text: String? {
        get {
            guard let cString = dc_msg_get_text(messagePointer) else { return nil }
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        set {
            if let newValue = newValue {
                dc_msg_set_text(messagePointer, newValue.cString(using: .utf8))
            } else {
                dc_msg_set_text(messagePointer, nil)
            }
        }
    }

    public var subject: String {
        guard let cString = dc_msg_get_subject(messagePointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var quoteText: String? {
        guard let cString = dc_msg_get_quoted_text(messagePointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var quoteMessage: DcMsg? {
        get {
            guard let msgpointer = dc_msg_get_quoted_msg(messagePointer) else { return nil }
            return DcMsg(pointer: msgpointer)
        }
        set {
            dc_msg_set_quote(messagePointer, newValue?.messagePointer)
        }
    }

    public var parent: DcMsg? {
        guard let msgpointer = dc_msg_get_parent(messagePointer) else { return nil }
        return DcMsg(pointer: msgpointer)
    }

    public var downloadState: Int32 {
        return dc_msg_get_download_state(messagePointer)
    }

    public var viewtype: MessageViewType? {
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
        case DC_MSG_WEBXDC:
            return .webxdc
        default:
            return nil
        }
    }

    public var fileURL: URL? {
        if let file = self.file {
            return URL(fileURLWithPath: file, isDirectory: false)
        }
        return nil
    }

    public lazy var image: UIImage? = {
        let filetype = dc_msg_get_viewtype(messagePointer)
        if let path = fileURL, filetype == DC_MSG_IMAGE || filetype == DC_MSG_GIF || filetype == DC_MSG_STICKER {
            if path.isFileURL {
                do {
                    let data = try Data(contentsOf: path)
                    let image = UIImage(data: data)
                    return image
                } catch {
                    print("failed to load image: \(path), \(error)")
                    return nil
                }
            }
            return nil
        } else {
            return nil
        }
    }()

    public func getWebxdcBlob(filename: String) -> Data {
        let ptrSize = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            ptrSize.deallocate()
        }

        guard let ccharPtr = dc_msg_get_webxdc_blob(messagePointer, filename, ptrSize) else {
            return Data()
        }
        defer {
            dc_str_unref(ccharPtr)
        }

        let count = ptrSize.pointee
        let buffer = UnsafeBufferPointer<Int8>(start: ccharPtr, count: count)
        let data = Data(buffer: buffer)
        return data
    }

    public func getWebxdcInfoJson() -> String {
        guard let cString = dc_msg_get_webxdc_info(messagePointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var messageHeight: CGFloat {
        return CGFloat(dc_msg_get_height(messagePointer))
    }

    public var messageWidth: CGFloat {
        return CGFloat(dc_msg_get_width(messagePointer))
    }
    
    public var duration: Int {
        return Int(dc_msg_get_duration(messagePointer))
    }

    public func setLateFilingMediaSize(width: CGFloat, height: CGFloat, duration: Int) {
        dc_msg_latefiling_mediasize(messagePointer, Int32(width), Int32(height), Int32(duration))
    }

    public var file: String? {
        if let cString = dc_msg_get_file(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    public var filemime: String? {
        if let cString = dc_msg_get_filemime(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    public var filename: String? {
        if let cString = dc_msg_get_filename(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    public func setFile(filepath: String?, mimeType: String? = nil) {
        dc_msg_set_file(messagePointer, filepath, mimeType)
    }

    public func setDimension(width: CGFloat, height: CGFloat) {
        dc_msg_set_dimension(messagePointer, Int32(width), Int32(height))
    }

    public var filesize: Int {
        return Int(dc_msg_get_filebytes(messagePointer))
    }

    // DC_MSG_*
    public var type: Int {
        return Int(dc_msg_get_viewtype(messagePointer))
    }

    // DC_STATE_*
    public var state: Int {
        return Int(dc_msg_get_state(messagePointer))
    }

    public var timestamp: Int64 {
        return Int64(dc_msg_get_timestamp(messagePointer))
    }

    public var isInfo: Bool {
        return dc_msg_is_info(messagePointer) == 1
    }

    public var isSetupMessage: Bool {
        return dc_msg_is_setupmessage(messagePointer) == 1
    }

    public var hasHtml: Bool {
        return dc_msg_has_html(messagePointer) == 1
    }
    
    public var hasLocation: Bool {
        return dc_msg_has_location(messagePointer) == 1
    }

    public var setupCodeBegin: String {
        guard let cString = dc_msg_get_setupcodebegin(messagePointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func summary(chars: Int) -> String? {
        guard let cString = dc_msg_get_summarytext(messagePointer, Int32(chars)) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func summary(chat: DcChat) -> DcLot {
        guard let chatPointer = chat.chatPointer else {
            return DcLot(nil)
        }
        guard let dcLotPointer = dc_msg_get_summary(messagePointer, chatPointer) else {
            return DcLot(nil)
        }
        return DcLot(dcLotPointer)
    }

    public func showPadlock() -> Bool {
        return dc_msg_get_showpadlock(messagePointer) == 1
    }

    public func getVideoChatUrl() -> String {
        guard let cString = dc_msg_get_videochat_url(messagePointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

}

public class DcContact {
    private var contactPointer: OpaquePointer?

    public init(contactPointer: OpaquePointer?) {
        self.contactPointer = contactPointer
    }

    deinit {
        dc_contact_unref(contactPointer)
    }

    public var displayName: String {
        guard let cString = dc_contact_get_display_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var nameNAddr: String {
        guard let cString = dc_contact_get_name_n_addr(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var editedName: String {
        guard let cString = dc_contact_get_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var authName: String {
        guard let cString = dc_contact_get_auth_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var email: String {
        guard let cString = dc_contact_get_addr(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var lastSeen: Int64 {
        return Int64(dc_contact_get_last_seen(contactPointer))
    }

    public var wasSeenRecently: Bool {
        return dc_contact_was_seen_recently(contactPointer) == 1
    }

    public var status: String {
        guard let cString = dc_contact_get_status(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var isVerified: Bool {
        return dc_contact_is_verified(contactPointer) > 0
    }

    public var isBlocked: Bool {
        return dc_contact_is_blocked(contactPointer) == 1
    }

    public lazy var profileImage: UIImage? = {
        guard let cString = dc_contact_get_profile_image(contactPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        if path.isFileURL {
            do {
                let data = try Data(contentsOf: path)
                return UIImage(data: data)
            } catch {
                print("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
    }()

    public var profileImageURL: URL? {
        guard let cString = dc_contact_get_profile_image(contactPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        return URL(fileURLWithPath: filename, isDirectory: false)
    }

    public var color: UIColor {
        return UIColor(netHex: Int(dc_contact_get_color(contactPointer)))
    }

    public var id: Int {
        return Int(dc_contact_get_id(contactPointer))
    }
}

public class DcLot {
    private var dcLotPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(_ dcLotPointer: OpaquePointer?) {
        self.dcLotPointer = dcLotPointer
    }

    deinit {
        dc_lot_unref(dcLotPointer)
    }

    public var text1: String? {
        guard let cString = dc_lot_get_text1(dcLotPointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var text1Meaning: Int {
        return Int(dc_lot_get_text1_meaning(dcLotPointer))
    }

    public var text2: String? {
        guard let cString = dc_lot_get_text2(dcLotPointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var timestamp: Int64 {
        return Int64(dc_lot_get_timestamp(dcLotPointer))
    }

    public var state: Int {
        return Int(dc_lot_get_state(dcLotPointer))
    }

    public var id: Int {
        return Int(dc_lot_get_id(dcLotPointer))
    }
}

public class DcProvider {
    private var dcProviderPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(_ dcProviderPointer: OpaquePointer) {
        self.dcProviderPointer = dcProviderPointer
    }

    deinit {
        dc_provider_unref(dcProviderPointer)
    }

    public var status: Int {
        return Int(dc_provider_get_status(dcProviderPointer))
    }

    public var beforeLoginHint: String {
        guard let cString = dc_provider_get_before_login_hint(dcProviderPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var getOverviewPage: String {
        guard let cString = dc_provider_get_overview_page(dcProviderPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }
}

public enum MessageViewType: CustomStringConvertible {
    case audio
    case file
    case gif
    case image
    case text
    case video
    case voice
    case webxdc

    public var description: String {
        switch self {
        // Use Internationalization, as appropriate.
        case .audio: return "Audio"
        case .file: return "File"
        case .gif: return "GIF"
        case .image: return "Image"
        case .text: return "Text"
        case .video: return "Video"
        case .voice: return "Voice"
        case .webxdc: return "Webxdc"
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
