import Foundation
import UIKit

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

extension ChatInputTextView: UIDropInteractionDelegate {
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: UIImage.self)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            return UIDropProposal(operation: .copy)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { imageItems in
            if let images = imageItems as? [UIImage] {
                self.imagePasteDelegate?.onImageDragAndDropped(image: images[0])
            }
        }
    }
}

public protocol ChatInputTextViewPasteDelegate: class {
    func onImagePasted(image: UIImage)
    func onImageDragAndDropped(image: UIImage)
}
