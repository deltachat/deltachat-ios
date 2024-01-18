import Foundation

/// An object representing a single chatlist in memory
///
/// See [dc_chatlist_t Class Reference](https://c.delta.chat/classdc__chatlist__t.html)
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
