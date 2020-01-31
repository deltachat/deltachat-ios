//
//  ContactCellViewModel.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 31.01.20.
//  Copyright © 2020 Jonas Reinsch. All rights reserved.
//

/*
 this file and the containing classes are manually imported from searchBarContactList-branch which has not been merged into master at this time. Once it has been merged, this file can be deleted.
 */

import Foundation

protocol AvatarCellViewModel {
    var type: CellModel { get }
    var title: String { get }
    var titleHighlightIndexes: [Int] { get }
    var subtitle: String { get }
    var subtitleHighlightIndexes: [Int] { get }
}

enum CellModel {
    case CONTACT(ContactCellData)
    case CHAT(ChatCellData)
}

struct ContactCellData {
    let contactId: Int
}

struct ChatCellData {
    let chatId: Int
    let summary: DcLot
    let unreadMessages: Int
}

class ContactCellViewModel: AvatarCellViewModel {

    private let contact: DcContact

    var type: CellModel
    var title: String {
        return contact.displayName
    }
    var subtitle: String {
        return contact.email
    }

    var avartarTitle: String {
        return Utils.getInitials(inputName: title)
    }

    var titleHighlightIndexes: [Int]
    var subtitleHighlightIndexes: [Int]

    init(contactData: ContactCellData, titleHighlightIndexes: [Int] = [], subtitleHighlightIndexes: [Int] = []) {
        type = CellModel.CONTACT(contactData)
        self.titleHighlightIndexes = titleHighlightIndexes
        self.subtitleHighlightIndexes = subtitleHighlightIndexes
        self.contact = DcContact(id: contactData.contactId)
    }
}

class ChatCellViewModel: AvatarCellViewModel{

    private let chat: DcChat
    private let summary: DcLot

    var type: CellModel
    var title: String {
        return chat.name
    }

    var subtitle: String {
        let result1 = summary.text1 ?? ""
        let result2 = summary.text2 ?? ""
        let result: String
        if !result1.isEmpty, !result2.isEmpty {
            result = "\(result1): \(result2)"
        } else {
            result = "\(result1)\(result2)"
        }
        return result
    }

    var titleHighlightIndexes: [Int]
    var subtitleHighlightIndexes: [Int]

    init(chatData: ChatCellData, titleHighlightIndexes: [Int] = [], subtitleHighlightIndexes: [Int] = []) {
        self.type = CellModel.CHAT(chatData)
        self.titleHighlightIndexes = titleHighlightIndexes
        self.subtitleHighlightIndexes = subtitleHighlightIndexes
        self.summary = chatData.summary
        self.chat = DcChat(id: chatData.chatId)
    }
}
