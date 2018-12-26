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
            let path: URL = URL.init(fileURLWithPath: filename, isDirectory: false)
            if path.isFileURL {
                do {
                    let data = try Data(contentsOf: path)
                    let image = UIImage(data: data)
                    return image
                } catch {
                    print("failed to load image", error, filename)
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
        return MRContact(id: fromContactId)
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
            let path: URL = URL.init(fileURLWithPath: filename, isDirectory: false)
            if path.isFileURL {
                do {
                    let data = try Data(contentsOf: path)
                    let image = UIImage(data: data)
                    return image
                } catch {
                    print("failed to load image", error, filename)
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
        //return Int(chatListPointer.pointee.m_cnt)
    }
    
    // takes ownership of specified pointer
    init(chatListPointer: UnsafeMutablePointer<dc_chatlist_t>) {
        self.chatListPointer = chatListPointer
    }
    
    func getChatId(index: Int) -> Int {
        return Int(dc_chatlist_get_chat_id(self.chatListPointer, index))
    }
    
    func getMessageId(index: Int) -> Int {
        return Int(dc_chatlist_get_msg_id(self.chatListPointer, index))
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
