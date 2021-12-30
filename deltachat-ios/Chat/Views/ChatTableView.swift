import UIKit

class ChatTableView: UITableView {

    var messageInputBar: InputBarAccessoryView
    
    override var inputAccessoryView: UIView? {
        return messageInputBar
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    public init(messageInputBar: InputBarAccessoryView) {
        self.messageInputBar = messageInputBar
        super.init(frame: .zero, style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
