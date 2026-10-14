import Foundation
import DcCore
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

public class ChatDropInteraction: NSObject {

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

    public func dropInteraction(performDrop session: UIDropSession, dcContext: DcContext) {
        guard let provider = session.items.first?.itemProvider else { return }
        Task { [weak self] in
            do {
                let provider = try await CodableNSItemProvider(from: provider, in: .temporaryDirectory)
                switch provider {
                case .text(let text):
                    self?.delegate?.onTextDragAndDropped(text: text)
                case .contentsAt(let url, DC_MSG_GIF), .contentsAt(let url, DC_MSG_IMAGE):
                    guard let image = UIImage.sd_image(with: try? Data(contentsOf: url)) else { return }
                    try? FileManager.default.removeItem(at: url)
                    self?.delegate?.onImageDragAndDropped(image: image)
                case .contentsAt(let url, DC_MSG_VIDEO):
                    url.convertToMp4(dcContext: dcContext) { compressedUrl, _ in
                        self?.delegate?.onVideoDragAndDropped(url: (compressedUrl ?? url) as NSURL)
                    }
                case .contentsAt(let url, _):
                    self?.delegate?.onFileDragAndDropped(url: url as NSURL)
                }
            } catch {
                logger.error("failed to get file for dropped item")
            }
        }
    }
}

extension ChatDropInteraction: UIDropInteractionDelegate {
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return dropInteraction(canHandle: session)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return dropInteraction(sessionDidUpdate: session)
    }

    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession, dcContext: DcContext) {
        dropInteraction(performDrop: session, dcContext: dcContext)
    }
}

public protocol ChatDropInteractionDelegate: AnyObject {
    func onImageDragAndDropped(image: UIImage)
    func onVideoDragAndDropped(url: NSURL)
    func onFileDragAndDropped(url: NSURL)
    func onTextDragAndDropped(text: String)
}
