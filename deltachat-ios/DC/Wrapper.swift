//
//  Wrapper.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 09.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import Foundation
import MessageKit
import UIKit

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
    return Int(contactPointer.pointee.id)
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

class MRMessage: MessageType {
  private var messagePointer: UnsafeMutablePointer<dc_msg_t>

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
    return Int(messagePointer.pointee.id)
  }

  var fromContactId: Int {
    return Int(messagePointer.pointee.from_id)
  }

  lazy var fromContact: MRContact = {
    MRContact(id: fromContactId)
  }()

  lazy var toContact: MRContact = {
    MRContact(id: toContactId)
  }()

  var toContactId: Int {
    return Int(messagePointer.pointee.to_id)
  }

  var chatId: Int {
    return Int(messagePointer.pointee.chat_id)
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

  lazy var image: UIImage? = { [unowned self] in
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

      return str == "" ? nil : str
    }

    return nil
  }

  var filemime: String? {
    if let cStr = dc_msg_get_filemime(messagePointer) {
      let str = String(cString: cStr)

      return str == "" ? nil : str
    }

    return nil
  }

  var filename: String? {
    if let cStr = dc_msg_get_filename(messagePointer) {
      let str = String(cString: cStr)

      return str == "" ? nil : str
    }

    return nil
  }

  var filesize: Int {
    return Int(dc_msg_get_filebytes(messagePointer))
  }

  // MR_MSG_*
  var type: Int {
    return Int(messagePointer.pointee.type)
  }

  // MR_STATE_*
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

  func createChat() -> MRChat {
    let chatId = dc_create_chat_by_msg_id(mailboxPointer, UInt32(id))
    return MRChat(id: Int(chatId))
  }

  deinit {
    dc_msg_unref(messagePointer)
  }
}

enum ChatType: Int {
  case SINGLE = 100
  case GROUP = 120
  case VERYFIEDGROUP = 130
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
      return str == "" ? nil : str
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

  private class var serverFlags: Int {
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
    sf = sf & ~0x700 // TODO: should be DC_LP_IMAP_SOCKET_FLAGS - could not be found
    sf = sf | flags
    serverFlags = sf
  }

  class func setSmtpSecurity(smptpFlags flags: Int) {
    var sf = serverFlags
    sf = sf & ~0x70000 // TODO: should be DC_LP_SMTP_SOCKET_FLAGS - could not be found
    sf = sf | flags
    serverFlags = sf
  }

  class func setAuthFlags(flags: Int) {
    var sf = serverFlags
    sf = sf & ~0x6 // TODO: should be DC_LP_AUTH_FLAGS - could not be found
    sf = sf | flags
    serverFlags = sf
  }

  // returns one of DC_LP_IMAP_SOCKET_STARTTLS, DC_LP_IMAP_SOCKET_SSL,
  class func getImapSecurity() -> Int {
    var sf = serverFlags
    sf = sf & 0x700
    return sf
  }

  // returns one of DC_LP_SMTP_SOCKET_STARTTLS, DC_LP_SMTP_SOCKET_SSL,
  class func getSmtpSecurity() -> Int {
    var sf = serverFlags
    sf = sf & 0x70000
    return sf
  }

  // returns on of DC_LP_AUTH_OAUTH2 or 0
  class func getAuthFlags() -> Int {
    var sf = serverFlags
    sf = sf & 0x6
    serverFlags = sf
    return sf
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
   *  DC_SHOW_EMAILS_OFF (0)= show direct replies to chats only (default),
   *  DC_SHOW_EMAILS_ACCEPTED_CONTACTS (1)= also show all mails of confirmed contacts,
   *  DC_SHOW_EMAILS_ALL (2)= also show mails of unconfirmed contacts in the deaddrop.
   */
  class var showEmails: Bool {
    set {
      setBool("show_emails", newValue)
    }
    get {
      return getBool("show_emails")
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

