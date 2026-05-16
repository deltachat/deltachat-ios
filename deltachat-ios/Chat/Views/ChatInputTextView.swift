import Foundation
import UIKit
import MobileCoreServices

public protocol ChatInputTextViewPasteDelegate: AnyObject {
    func onImagePasted(_ image: UIImage)
}

public class ChatInputTextView: UITextView {
    public weak var imagePasteDelegate: ChatInputTextViewPasteDelegate?

    // MARK: - Image Paste Support
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == NSSelectorFromString("paste:") && UIPasteboard.general.hasImagesExtended {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    open override func paste(_ sender: Any?) {
        guard let image = UIPasteboard.general.imageExtended else {
            return super.paste(sender)
        }
        imagePasteDelegate?.onImagePasted(image)
    }
}

