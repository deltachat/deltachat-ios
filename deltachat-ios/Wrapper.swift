//
//  Wrapper.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 09.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import Foundation
import UIKit

class MRContact {
    private var contactPointer: UnsafeMutablePointer<dc_contact_t>

    var name: String {
        if contactPointer.pointee.name == nil {
            return email
        }
        let name = String(cString: contactPointer.pointee.name)
        if name.isEmpty {
            return email
        }
        return name
    }

    var email: String {
        if contactPointer.pointee.addr == nil {
            return "error: no email in contact"
        }
        return String(cString: contactPointer.pointee.addr)
    }

    var isVerified: Bool {
        return dc_contact_is_verified(contactPointer) == 1
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
        return Int(contactPointer.pointee.id)
    }

    init(id: Int) {
        contactPointer = dc_get_contact(mailboxPointer, UInt32(id))
    }

    deinit {
        dc_contact_unref(contactPointer)
    }
}

class MRMessage {
    private var messagePointer: UnsafeMutablePointer<dc_msg_t>

    var id: Int {
        return Int(messagePointer.pointee.id)
    }

    var fromContactId: Int {
        return Int(messagePointer.pointee.from_id)
    }

    lazy var fromContact: MRContact = {
        MRContact(id: fromContactId)
    }()

    var toContactId: Int {
        return Int(messagePointer.pointee.to_id)
    }

    var chatId: Int {
        return Int(messagePointer.pointee.chat_id)
    }

    var text: String? {
        return String(cString: messagePointer.pointee.text)
    }

    var mimeType: String? {
        guard let result = dc_msg_get_filemime(messagePointer) else { return nil }
        return String(cString: result)
    }

    lazy var image: UIImage? = { [unowned self] in
        let filetype = dc_msg_get_viewtype(messagePointer)
        let file = dc_msg_get_file(messagePointer)
        if let cFile = file, filetype == DC_MSG_IMAGE {
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
        } else {
            return nil
        }
    }()

    // MR_MSG_*
    var type: Int {
        return Int(messagePointer.pointee.type)
    }

    // MR_STATE_*
    var state: Int {
        return Int(messagePointer.pointee.state)
    }

    func stateOutDescription() -> String {
        switch Int32(state) {
        case DC_STATE_OUT_DRAFT:
            return "Draft"
        case DC_STATE_OUT_PENDING:
            return "Pending"
        case DC_STATE_OUT_DELIVERED:
            return "Sent"
        case DC_STATE_OUT_MDN_RCVD:
            return "Read"
        default:
            return "Unknown"
        }
    }

    var timestamp: Int64 {
        return Int64(messagePointer.pointee.timestamp)
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

    deinit {
        dc_msg_unref(messagePointer)
    }
}

class MRChat {
    var chatPointer: UnsafeMutablePointer<dc_chat_t>

    var id: Int {
        return Int(chatPointer.pointee.id)
    }

    var name: String {
        if chatPointer.pointee.name == nil {
            return "Error - no name"
        }
        return String(cString: chatPointer.pointee.name)
    }

    var type: Int {
        return Int(chatPointer.pointee.type)
    }

    var color: UIColor {
        return UIColor(netHex: Int(dc_chat_get_color(chatPointer)))
    }

    var isVerified: Bool {
        return dc_chat_is_verified(chatPointer) == 1
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

    init(id: Int) {
        chatPointer = dc_get_chat(mailboxPointer, UInt32(id))
    }

    deinit {
        dc_chat_unref(chatPointer)
    }
}

class MRPoorText {
    private var poorTextPointer: UnsafeMutablePointer<dc_lot_t>

    var text1: String? {
        if poorTextPointer.pointee.text1 == nil {
            return nil
        }
        return String(cString: poorTextPointer.pointee.text1)
    }

    var text2: String? {
        if poorTextPointer.pointee.text2 == nil {
            return nil
        }
        return String(cString: poorTextPointer.pointee.text2)
    }

    var text1Meaning: Int {
        return Int(poorTextPointer.pointee.text1_meaning)
    }

    var timeStamp: Int {
        return Int(poorTextPointer.pointee.timestamp)
    }

    var state: Int {
        return Int(poorTextPointer.pointee.state)
    }

    // takes ownership of specified pointer
    init(poorTextPointer: UnsafeMutablePointer<dc_lot_t>) {
        self.poorTextPointer = poorTextPointer
    }

    deinit {
        dc_lot_unref(poorTextPointer)
    }
}

class MRChatList {
    private var chatListPointer: UnsafeMutablePointer<dc_chatlist_t>

    var length: Int {
        return dc_chatlist_get_cnt(chatListPointer)
        // return Int(chatListPointer.pointee.m_cnt)
    }

    // takes ownership of specified pointer
    init(chatListPointer: UnsafeMutablePointer<dc_chatlist_t>) {
        self.chatListPointer = chatListPointer
    }

    func getChatId(index: Int) -> Int {
        return Int(dc_chatlist_get_chat_id(chatListPointer, index))
    }

    func getMessageId(index: Int) -> Int {
        return Int(dc_chatlist_get_msg_id(chatListPointer, index))
    }

    func summary(index: Int) -> MRPoorText {
        guard let poorTextPointer = dc_chatlist_get_summary(self.chatListPointer, index, nil) else {
            fatalError("poor text pointer was nil")
        }
        return MRPoorText(poorTextPointer: poorTextPointer)
    }

    deinit {
        dc_chatlist_unref(chatListPointer)
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

class MRConfig {
    private class func getOptStr(_ key: String) -> String? {
        let p = dc_get_config(mailboxPointer, key)

        if let pSafe = p {
            let c = String(cString: pSafe)
            if c == "" {
                return nil
            }
            return c
        }

        return nil
    }

    private class func setOptStr(_ key: String, _ value: String?) {
        if let v = value {
            dc_set_config(mailboxPointer, key, v)
        }
    }

    private class func getBool(_ key: String) -> Bool {
        return strToBool(getOptStr(key))
    }

    private class func setBool(_ key: String, _ value: Bool) {
        let vStr = value ? "1" : "0"
        setOptStr(key, vStr)
    }

    /**
     *  Address to display (always needed)
     */
    class var addr: String? {
        set {
            setOptStr("addr", newValue)
        }
        get {
            return getOptStr("addr")
        }
    }

    /**
     *  IMAP-server, guessed if left out
     */
    class var mailServer: String? {
        set {
            setOptStr("mail_server", newValue)
        }
        get {
            return getOptStr("mail_server")
        }
    }

    /**
     *  IMAP-username, guessed if left out
     */
    class var mailUser: String? {
        set {
            setOptStr("mail_user", newValue)
        }
        get {
            return getOptStr("mail_user")
        }
    }

    /**
     *  IMAP-password (always needed)
     */
    class var mailPw: String? {
        set {
            setOptStr("mail_pw", newValue)
        }
        get {
            return getOptStr("mail_pw")
        }
    }

    /**
     *  IMAP-port, guessed if left out
     */
    class var mailPort: String? {
        set {
            setOptStr("mail_port", newValue)
        }
        get {
            return getOptStr("mail_port")
        }
    }

    /**
     *  SMTP-server, guessed if left out
     */
    class var sendServer: String? {
        set {
            setOptStr("send_server", newValue)
        }
        get {
            return getOptStr("send_server")
        }
    }

    /**
     *  SMTP-user, guessed if left out
     */
    class var sendUser: String? {
        set {
            setOptStr("send_user", newValue)
        }
        get {
            return getOptStr("send_user")
        }
    }

    /**
     *  SMTP-password, guessed if left out
     */
    class var sendPw: String? {
        set {
            setOptStr("send_pw", newValue)
        }
        get {
            return getOptStr("send_pw")
        }
    }

    /**
     * SMTP-port, guessed if left out
     */
    class var sendPort: String? {
        set {
            setOptStr("send_port", newValue)
        }
        get {
            return getOptStr("send_port")
        }
    }

    /**
     * IMAP-/SMTP-flags as a combination of DC_LP flags, guessed if left out
     */
    class var serverFlags: String? {
        set {
            setOptStr("server_flags", newValue)
        }
        get {
            return getOptStr("server_flags")
        }
    }

    /**
     * Own name to use when sending messages. MUAs are allowed to spread this way eg. using CC, defaults to empty
     */
    class var displayname: String? {
        set {
            setOptStr("displayname", newValue)
        }
        get {
            return getOptStr("displayname")
        }
    }

    /**
     * Own status to display eg. in email footers, defaults to a standard text
     */
    class var selfstatus: String? {
        set {
            setOptStr("selfstatus", newValue)
        }
        get {
            return getOptStr("selfstatus")
        }
    }

    /**
     * File containing avatar. Will be copied to blob directory. NULL to remove the avatar. It is planned for future versions to send this image together with the next messages.
     */
    class var selfavatar: String? {
        set {
            setOptStr("selfavatar", newValue)
        }
        get {
            return getOptStr("selfavatar")
        }
    }

    /**
     * 0=no end-to-end-encryption, 1=prefer end-to-end-encryption (default)
     */
    class var e2eeEnabled: Bool {
        set {
            setBool("e2ee_enabled", newValue)
        }
        get {
            return getBool("e2ee_enabled")
        }
    }

    /**
     * 0=do not send or request read receipts, 1=send and request read receipts (default)
     */
    class var mdnsEnabled: Bool {
        set {
            setBool("mdns_enabled", newValue)
        }
        get {
            return getBool("mdns_enabled")
        }
    }

    /**
     * 1=watch INBOX-folder for changes (default), 0=do not watch the INBOX-folder
     */
    class var inboxWatch: Bool {
        set {
            setBool("inbox_watch", newValue)
        }
        get {
            return getBool("inbox_watch")
        }
    }

    /**
     * 1=watch Sent-folder for changes (default), 0=do not watch the Sent-folder
     */
    class var sentboxWatch: Bool {
        set {
            setBool("sentbox_watch", newValue)
        }
        get {
            return getBool("sentbox_watch")
        }
    }

    /**
     * 1=watch DeltaChat-folder for changes (default), 0=do not watch the DeltaChat-folder
     */
    class var mvboxWatch: Bool {
        set {
            setBool("mvbox_watch", newValue)
        }
        get {
            return getBool("mvbox_watch")
        }
    }

    /**
     * 1=heuristically detect chat-messages and move them to the DeltaChat-folder, 0=do not move chat-messages
     */
    class var mvboxMove: Bool {
        set {
            setBool("mvbox_move", newValue)
        }
        get {
            return getBool("mvbox_move")
        }
    }

    /**
     * 1=save mime headers and make dc_get_mime_headers() work for subsequent calls, 0=do not save mime headers (default)
     */
    class var saveMimeHeaders: Bool {
        set {
            setBool("save_mime_headers", newValue)
        }
        get {
            return getBool("save_mime_headers")
        }
    }

    class var configuredEmail: String {
        get {
            return getOptStr("configured_addr") ?? ""
        }
        set {}
    }

    class var configuredMailServer: String {
        get {
            return getOptStr("configured_mail_server") ?? ""
        }
        set {}
    }

    class var configuredMailUser: String {
        get {
            return getOptStr("configured_mail_user") ?? ""
        }
        set {}
    }

    class var configuredMailPw: String {
        get {
            return getOptStr("configured_mail_pw") ?? ""
        }
        set {}
    }

    class var configuredMailPort: String {
        get {
            return getOptStr("configured_mail_port") ?? ""
        }
        set {}
    }

    class var configuredSendServer: String {
        get {
            return getOptStr("configured_send_server") ?? ""
        }
        set {}
    }

    class var configuredSendUser: String {
        get {
            return getOptStr("configured_send_user") ?? ""
        }
        set {}
    }

    class var configuredSendPw: String {
        get {
            return getOptStr("configured_send_pw") ?? ""
        }
        set {}
    }

    class var configuredSendPort: String {
        get {
            return getOptStr("configured_send_port") ?? ""
        }
        set {}
    }

    class var configuredServerFlags: String {
        get {
            return getOptStr("configured_server_flags") ?? ""
        }
        set {}
    }

    /**
     * Was configured executed beforeß
     */
    class var configured: Bool {
        get {
            return getBool("configured")
        }
        set {}
    }
}
