
import Foundation

extension DcChat {
    convenience init(id: Int) {
        self.init(dcContextPointer: mailboxPointer, id: id)
    }
}
