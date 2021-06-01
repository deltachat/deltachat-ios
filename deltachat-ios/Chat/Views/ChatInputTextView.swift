import Foundation
import InputBarAccessoryView

public class ChatInputTextView: InputTextView {

    public weak var imagePasteDelegate: ChatInputTextViewPasteDelegate?

    // MARK: - Image Paste Support
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == NSSelectorFromString("paste:") && UIPasteboard.general.image != nil {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    open override func paste(_ sender: Any?) {
        guard let image = UIPasteboard.general.image else {
            return super.paste(sender)
        }
        imagePasteDelegate?.onImagePasted(image: image)
    }
}


public protocol ChatInputTextViewPasteDelegate: class {
    func onImagePasted(image: UIImage)
}
