import Foundation
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

public class ChatDropInteraction {

    public weak var delegate: ChatDropInteractionDelegate?

    public func dropInteraction(canHandle session: UIDropSession) -> Bool {
        if #available(iOS 14.0, *) {
            return  session.items.count == 1 && session.hasItemsConforming(toTypeIdentifiers: [
                UTType.image.identifier,
                UTType.video.identifier,
                UTType.movie.identifier,
                UTType.text.identifier,
                UTType.item.identifier])
        }
        return session.items.count == 1 && session.hasItemsConforming(toTypeIdentifiers: [
            kUTTypeImage as String,
            kUTTypeText as String,
            kUTTypeMovie as String,
            kUTTypeVideo as String,
            kUTTypeItem as String])
    }

    public func dropInteraction(sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            return UIDropProposal(operation: .copy)
    }

    public func dropInteraction(performDrop session: UIDropSession) {
        if #available(iOS 15.0, *) {
            if session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier]) {
               loadImageObjects(session: session)
            } else if session.hasItemsConforming(toTypeIdentifiers: [UTType.movie.identifier, UTType.video.identifier]) {
                loadFileObjects(session: session, isVideo: true)
            } else if session.hasItemsConforming(toTypeIdentifiers: [UTType.item.identifier]) {
                loadFileObjects(session: session)
            } else if session.hasItemsConforming(toTypeIdentifiers: [UTType.text.identifier]) {
                loadTextObjects(session: session)
            }
        } else {
            if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeImage as String]) {
               loadImageObjects(session: session)
            } else if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeMovie as String, kUTTypeVideo as String]) {
                loadFileObjects(session: session, isVideo: true)
            } else if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeItem as String]) {
                loadFileObjects(session: session)
            } else if session.hasItemsConforming(toTypeIdentifiers: [kUTTypeText as String]) {
                loadTextObjects(session: session)
            }
        }
    }

    private func loadImageObjects(session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] imageItems in
            if let images = imageItems as? [UIImage], !images.isEmpty {
                self?.delegate?.onImageDragAndDropped(image: images[0])
            }
        }
    }

    private func loadFileObjects(session: UIDropSession, isVideo: Bool = false) {
        if session.items.isEmpty {
            return
        }
        let item: UIDragItem = session.items[0]
        item.itemProvider.loadFileRepresentation(forTypeIdentifier: kUTTypeItem as String) { [weak self] (url, error) in
            guard let url = url else {
                if let error = error {
                    logger.error("error loading file \(error)")
                }
                return
            }
            DispatchQueue.global().async { [weak self] in
                let nsdata = NSData(contentsOf: url)
                guard let data = nsdata as? Data else { return }
                let name = url.deletingPathExtension().lastPathComponent
                guard let fileName = FileHelper.saveData(data: data,
                                                         name: name,
                                                         suffix: url.pathExtension,
                                                         directory: .cachesDirectory) else { return }
                DispatchQueue.main.async {
                    if isVideo {
                        self?.delegate?.onVideoDragAndDropped(url: NSURL(fileURLWithPath: fileName))
                    } else {
                        self?.delegate?.onFileDragAndDropped(url: NSURL(fileURLWithPath: fileName))
                    }
                }
            }
        }
    }

    private func loadTextObjects(session: UIDropSession) {
        _ = session.loadObjects(ofClass: String.self) { [weak self] stringItems in
            guard !stringItems.isEmpty else { return }
            self?.delegate?.onTextDragAndDropped(text: stringItems[0])
        }
    }
}

public protocol ChatDropInteractionDelegate: class {
    func onImageDragAndDropped(image: UIImage)
    func onVideoDragAndDropped(url: NSURL)
    func onFileDragAndDropped(url: NSURL)
    func onTextDragAndDropped(text: String)
}
