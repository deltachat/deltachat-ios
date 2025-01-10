import Foundation
import UIKit
import MobileCoreServices

public class ChatInputTextView: InputTextView {

    public weak var imagePasteDelegate: ChatInputTextViewPasteDelegate?
    private lazy var dropInteraction: ChatDropInteraction = {
        return ChatDropInteraction()
    }()

    public func setDropInteractionDelegate(delegate: ChatDropInteractionDelegate) {
        dropInteraction.delegate = delegate
    }

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
        imagePasteDelegate?.onImagePasted(image: image)
    }
}

extension ChatInputTextView: UIDropInteractionDelegate {
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return dropInteraction.dropInteraction(canHandle: session)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return dropInteraction.dropInteraction(sessionDidUpdate: session)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        dropInteraction.dropInteraction(performDrop: session)
    }
}

public protocol ChatInputTextViewPasteDelegate: AnyObject {
    func onImagePasted(image: UIImage)
}
