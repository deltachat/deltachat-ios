import Foundation
import UIKit
import MobileCoreServices

public class ChatInputTextView: InputTextView {

    public weak var textViewPasteDelegate: ChatInputTextViewPasteDelegate?

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
        textViewPasteDelegate?.onImagePasted(image: image)
    }
}

extension ChatInputTextView: UIDropInteractionDelegate {
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return  session.items.count == 1 && session.hasItemsConforming(toTypeIdentifiers: [kUTTypeImage as String, kUTTypeText as String, kUTTypeMovie as String, kUTTypeVideo as String])
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            return UIDropProposal(operation: .copy)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeImage as String]) {
            session.loadObjects(ofClass: UIImage.self) { [weak self] imageItems in
                if let images = imageItems as? [UIImage] {
                    self?.textViewPasteDelegate?.onImageDragAndDropped(image: images[0])
                }
            }
        } else if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeMovie as String, kUTTypeVideo as String]) {
            session.loadObjects(ofClass: NSData.self) { [weak self] videoItems in
                if let videos = videoItems as? [NSData] {
                    let video = videos[0] as Data
                    if let mimeType = Swime.mimeType(data: video) {
                        DispatchQueue.global().async { [weak self] in
                            if let fileName = FileHelper.saveData(data: video, name: "tmp_dragAndDrop", suffix: mimeType.ext, directory: .cachesDirectory) {
                                DispatchQueue.main.async {
                                    self?.textViewPasteDelegate?.onVideoDragAndDropped(url: URL(fileURLWithPath: fileName))
                                }
                            }
                        }
                    }
                }
            }
        } else if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeText as String]) {
            session.loadObjects(ofClass: String.self) { [weak self] stringItems in
                if let isEmpty = self?.text.isEmpty, isEmpty {
                    self?.text = stringItems[0]
                } else {
                    var updatedText = self?.text
                    updatedText?.append(" \(stringItems[0]) ")
                    self?.text = updatedText
                }
            }
        }
    }
}

public protocol ChatInputTextViewPasteDelegate: class {
    func onImagePasted(image: UIImage)
    func onImageDragAndDropped(image: UIImage)
    func onVideoDragAndDropped(url: URL)
}
