import UIKit
import InputBarAccessoryView

public class ChatInputBar: InputBarAccessoryView {

    var hasDraft: Bool = false
    var hasQuote: Bool = false

    override open func calculateMaxTextViewHeight() -> CGFloat {
        let divisor: CGFloat = traitCollection.verticalSizeClass == .regular ? 3 : 5
        var subtract: CGFloat = 0
        subtract += hasDraft ? 90 : 0
        subtract += hasQuote ? 90 : 0
        let height = (UIScreen.main.bounds.height / divisor).rounded(.down) - subtract
        if height < 40 {
            return 40
        }
        return height
    }

    public func configure(draft: DraftModel) {
        hasDraft = draft.draftAttachment != nil
        hasQuote = draft.quoteText != nil
        maxTextViewHeight = calculateMaxTextViewHeight()
    }

    public func cancel() {
        hasDraft = false
        hasQuote = false
        maxTextViewHeight = calculateMaxTextViewHeight()
    }
}
