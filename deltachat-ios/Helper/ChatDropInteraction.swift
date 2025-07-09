import Foundation
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

public class ChatDropInteraction {

    public weak var delegate: ChatDropInteractionDelegate?

    public func dropInteraction(canHandle session: UIDropSession) -> Bool {
        session.items.count == 1 && session.hasItemsConforming(toTypeIdentifiers: [
            UTType.image.identifier,
            UTType.mpeg4Movie.identifier,
            UTType.quickTimeMovie.identifier,
            UTType.video.identifier,
            UTType.movie.identifier,
            UTType.text.identifier,
            UTType.url.identifier,
            UTType.item.identifier])
    }

    public func dropInteraction(sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            return UIDropProposal(operation: .copy)
    }

    public func dropInteraction(performDrop session: UIDropSession) {
        if session.items.first?.itemProvider.canLoadImage(allowAnimated: true) == true {
            loadImageObjects(session: session)
        } else if session.items.first?.itemProvider.canLoadVideo() == true {
            loadVideoObjects(session: session)
        } else if session.hasItemsConforming(toTypeIdentifiers: [UTType.url.identifier]) {
            loadTextObjects(session: session)
        } else if session.hasItemsConforming(toTypeIdentifiers: [UTType.text.identifier]) {
            loadTextObjects(session: session)
        } else if session.hasItemsConforming(toTypeIdentifiers: [UTType.item.identifier]) {
            loadFileObjects(session: session)
        }
    }

    private func loadImageObjects(session: UIDropSession) {
        guard let droppedItem = session.items.first else { return }
        droppedItem.itemProvider.loadImage(allowAnimated: true) { [weak self] image, _ in
            guard let image else { return }
            self?.delegate?.onImageDragAndDropped(image: image)
        }
    }
    
    private func loadVideoObjects(session: UIDropSession) {
        guard let droppedItem = session.items.first else { return }
        droppedItem.itemProvider.loadCompressedVideo { [weak self] videoUrl, _ in
            guard let videoUrl else { return }
            self?.delegate?.onVideoDragAndDropped(url: videoUrl as NSURL)
        }
    }

    private func loadFileObjects(session: UIDropSession) {
        guard let item = session.items.first else { return }
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
                    self?.delegate?.onFileDragAndDropped(url: NSURL(fileURLWithPath: fileName))
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

public protocol ChatDropInteractionDelegate: AnyObject {
    func onImageDragAndDropped(image: UIImage)
    func onVideoDragAndDropped(url: NSURL)
    func onFileDragAndDropped(url: NSURL)
    func onTextDragAndDropped(text: String)
}
