import UIKit
import DcCore

class ContactDetailViewModel {

    let context: DcContext

    enum ProfileSections {
        case chatOptions
        case sharedChats
        case chatActions
    }

    enum ChatOption {
        case gallery
        case documents
        case ephemeralMessages
        case muteChat
        case startChat
    }

    enum ChatAction {
        case archiveChat
        case blockContact
        case deleteChat
    }

    var contactId: Int

    var contact: DcContact {
        return DcContact(id: contactId)
    }

    let chatId: Int
    private let sharedChats: DcChatlist
    private var sections: [ProfileSections] = []
    private var chatActions: [ChatAction] = []
    private var chatOptions: [ChatOption] = []

    init(dcContext: DcContext, contactId: Int) {
        self.context = dcContext
        self.contactId = contactId
        self.chatId = dcContext.getChatIdByContactId(contactId: contactId)
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)

        sections.append(.chatOptions)
        if sharedChats.length > 0 {
            sections.append(.sharedChats)
        }
        sections.append(.chatActions)

        if chatId != 0 {
            chatOptions = [.gallery, .documents, .ephemeralMessages, .muteChat, .startChat]
            chatActions = [.archiveChat, .blockContact, .deleteChat]
        } else {
            chatOptions = [.gallery, .documents, .startChat]
            chatActions = [.blockContact]
        }
    }

    func typeFor(section: Int) -> ContactDetailViewModel.ProfileSections {
        return sections[section]
    }

    func chatActionFor(row: Int) -> ContactDetailViewModel.ChatAction {
        return chatActions[row]
    }

    func chatOptionFor(row: Int) -> ContactDetailViewModel.ChatOption {
        return chatOptions[row]
    }

    var chatIsArchived: Bool {
        return chatId != 0 && context.getChat(chatId: chatId).isArchived
    }

    var chatIsMuted: Bool {
        return chatId != 0 && context.getChat(chatId: chatId).isMuted
    }

    var chatIsEphemeral: Bool {
        return chatId != 0 && context.getChatEphemeralTimer(chatId: chatId) > 0
    }

    var galleryItemMessageIds: [Int] {
        return context.getChatMedia(
            chatId: chatId,
            messageType: DC_MSG_IMAGE,
            messageType2: DC_MSG_GIF,
            messageType3: DC_MSG_VIDEO
        )
    }

    var documentItemMessageIds: [Int] {
        return context.getChatMedia(
            chatId: chatId,
            messageType: DC_MSG_FILE,
            messageType2: DC_MSG_AUDIO,
            messageType3: 0
        )
    }

    var numberOfSections: Int {
        return sections.count
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch sections[section] {
        case .chatOptions: return chatOptions.count
        case .sharedChats: return sharedChats.length
        case .chatActions: return chatActions.count
        }
    }

    func getSharedChatIdAt(indexPath: IndexPath) -> Int {
        let index = indexPath.row
        return sharedChats.getChatId(index: index)
    }

    func update(sharedChatCell cell: ContactCell, row index: Int) {
        let chatId = sharedChats.getChatId(index: index)
        let summary = sharedChats.getSummary(index: index)
        let unreadMessages = context.getUnreadMessages(chatId: chatId)
        let cellData = ChatCellData(chatId: chatId, summary: summary, unreadMessages: unreadMessages)
        let cellViewModel = ChatCellViewModel(dcContext: context, chatData: cellData)
        cell.updateCell(cellViewModel: cellViewModel)
    }

    func titleFor(section: Int) -> String? {
        if sections[section] == .sharedChats {
            return String.localized("profile_shared_chats")
        }
        return nil
    }

    // returns true if chat is archived after action
    func toggleArchiveChat() -> Bool {
        if chatId == 0 {
            safe_fatalError("there is no chatId - you are probably are calling this from ContactDetail - this should be only called from ChatDetail")
            return false
        }
        context.archiveChat(chatId: chatId, archive: !chatIsArchived)
        return chatIsArchived
    }
}
