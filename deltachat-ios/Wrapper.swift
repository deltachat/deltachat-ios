//
//  Wrapper.swift
//  deltachat-ios
//
//  Created by Jonas Reinsch on 09.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import Foundation


class MRContact {
    private var contactPointer: UnsafeMutablePointer<mrcontact_t>
    
    var name: String {
        if contactPointer.pointee.m_name == nil {
            return email
        }
        let name = String(cString: contactPointer.pointee.m_name)
        if name.isEmpty {
            return email
        }
        return name
    }
    
    var email: String {
        if contactPointer.pointee.m_addr == nil {
            return "error: no email in contact"
        }
        return String(cString: contactPointer.pointee.m_addr)
    }
    
    var id: Int {
        return Int(contactPointer.pointee.m_id)
    }
    
    init(id: Int) {
        contactPointer = mrmailbox_get_contact(mailboxPointer, UInt32(id))
    }
    
    deinit {
        mrcontact_unref(contactPointer)
    }
}


class MRMessage {
    private var messagePointer: UnsafeMutablePointer<mrmsg_t>
    
    var id: Int {
        return Int(messagePointer.pointee.m_id)
    }
    
    var fromContactId: Int {
        return Int(messagePointer.pointee.m_from_id)
    }
    
    var toContactId: Int {
        return Int(messagePointer.pointee.m_to_id)
    }
    
    var chatId: Int {
        return Int(messagePointer.pointee.m_chat_id)
    }
    
    var text: String? {
        return String(cString: messagePointer.pointee.m_text)
    }
    
    // MR_MSG_*
    var type: Int {
        return Int(messagePointer.pointee.m_type)
    }
    
    // MR_STATE_*
    var state: Int {
        return Int(messagePointer.pointee.m_state)
    }
    
    var timestamp: Int64 {
        return Int64(messagePointer.pointee.m_timestamp)
    }
    
    init(id: Int) {
        messagePointer = mrmailbox_get_msg(mailboxPointer, UInt32(id))
    }
    
    deinit {
        mrmsg_unref(messagePointer)
    }
}

class MRChat {
    
    private var chatPointer: UnsafeMutablePointer<mrchat_t>
    
    var id: Int {
        return Int(chatPointer.pointee.m_id)
    }
    
    var name: String {
        if chatPointer.pointee.m_name == nil {
            return "Error - no name"
        }
        return String(cString: chatPointer.pointee.m_name)
    }
    
    var type: Int {
        return Int(chatPointer.pointee.m_type)
    }
    
    init(id: Int) {
        chatPointer = mrmailbox_get_chat(mailboxPointer, UInt32(id))
    }
    
    deinit {
        mrchat_unref(chatPointer)
    }
}

class MRPoorText {
    
    private var poorTextPointer: UnsafeMutablePointer<mrlot_t>
    
    var text1: String? {
        if poorTextPointer.pointee.m_text1 == nil {
            return nil
        }
        return String(cString: poorTextPointer.pointee.m_text1)
    }
    
    var text2: String? {
        if poorTextPointer.pointee.m_text2 == nil {
            return nil
        }
        return String(cString: poorTextPointer.pointee.m_text2)
    }
    
    var text1Meaning: Int {
        return Int(poorTextPointer.pointee.m_text1_meaning)
    }
    
    var timeStamp: Int {
        return Int(poorTextPointer.pointee.m_timestamp)
    }
    
    var state: Int {
        return Int(poorTextPointer.pointee.m_state)
    }
    
    // takes ownership of specified pointer
    init(poorTextPointer: UnsafeMutablePointer<mrlot_t>) {
        self.poorTextPointer = poorTextPointer
    }
    
    deinit {
        mrlot_unref(poorTextPointer)
    }
}

class MRChatList {
    
    private var chatListPointer: UnsafeMutablePointer<mrchatlist_t>
    
    var length: Int {
        return mrchatlist_get_cnt(chatListPointer)
        //return Int(chatListPointer.pointee.m_cnt)
    }
    
    // takes ownership of specified pointer
    init(chatListPointer: UnsafeMutablePointer<mrchatlist_t>) {
        self.chatListPointer = chatListPointer
    }
    
    func getChatId(index: Int) -> Int {
        return Int(mrchatlist_get_chat_id(self.chatListPointer, index))
    }
    
    func getMessageId(index: Int) -> Int {
        return Int(mrchatlist_get_msg_id(self.chatListPointer, index))
    }
    
    func summary(index: Int) -> MRPoorText {
        guard let poorTextPointer = mrchatlist_get_summary(self.chatListPointer, index, nil) else {
            fatalError("poor text pointer was nil")
        }
        return MRPoorText(poorTextPointer: poorTextPointer)
    }
    
    deinit {
        mrchatlist_unref(chatListPointer)
    }
}
