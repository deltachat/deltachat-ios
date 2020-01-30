import Foundation

protocol ContactDetailViewModelProtocol {
    var contactId: Int { get }
    var numberOfSections: Int { get }
    func numberOfRowsInSection(_ : Int) -> Int
    func updateCellAt(indexPath: IndexPath)
    func getSharedChatIdAt(indexPath: IndexPath) -> Int
}

class ContactDetailViewModel: ContactDetailViewModelProtocol {
    var contactId: Int

    private let sharedChats: DcChatlist

    init(contactId: Int, context: DcContext) {
        self.contactId = contactId
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)
    }

    var numberOfSections: Int {
        return 0
    }

    func numberOfRowsInSection(_: Int) -> Int {
        return 0
    }

    func updateCellAt(indexPath: IndexPath) {
        return
    }

    func getSharedChatIdAt(indexPath: IndexPath) -> Int {
        return 0
    }


}
