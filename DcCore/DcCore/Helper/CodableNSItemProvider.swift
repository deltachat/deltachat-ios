import Foundation
import UIKit
import UniformTypeIdentifiers

public var shareExtensionDirectory = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: DatabaseHelper.applicationGroupIdentifier)!
    .appendingPathComponent("share_extension", isDirectory: true)

/// An NSItemProvider wrapper that can be encoded and sent between extensions and main app process
public enum CodableNSItemProvider: Codable {
    case contentsAt(url: URL, viewType: Int32)
    case text(text: String)
    
    public func itemProvider() -> NSItemProvider? {
        switch self {
        case .contentsAt(let url, _):
            return NSItemProvider(contentsOf: url) ?? {
                logger.error("Failed to init NSItemProvider from contents of url: \(url)")
                return NSItemProvider(object: url as NSURL)
            }()
        case .text(let text):
            // Note: If text is a url, this will create an item conforming to UTType.url
            return NSItemProvider(object: NSString(string: text))
        }
    }
    
    public init(from provider: NSItemProvider) async throws {
        self = try await withCheckedThrowingContinuation { continuation in
            switch provider.hasItemConformingToTypeIdentifier {
            case UTType.gif.identifier: loadFileURL(forType: .gif, DC_MSG_GIF)
            case UTType.webP.identifier: loadFileURL(forType: .webP, DC_MSG_IMAGE)
            case UTType.png.identifier: loadFileURL(forType: .png, DC_MSG_IMAGE)
            case UTType.jpeg.identifier: loadFileURL(forType: .jpeg, DC_MSG_IMAGE)
            case UTType.image.identifier: loadFileURL(forType: .image, DC_MSG_IMAGE)
            case UTType.mpeg4Movie.identifier: loadFileURL(forType: .mpeg4Movie, DC_MSG_VIDEO)
            case UTType.quickTimeMovie.identifier: loadFileURL(forType: .quickTimeMovie, DC_MSG_VIDEO)
            case UTType.movie.identifier: loadFileURL(forType: .movie, DC_MSG_VIDEO)
            case UTType.video.identifier: loadFileURL(forType: .video, DC_MSG_VIDEO)
            case UTType.url.identifier: loadText(forType: .url)
            case UTType.text.identifier: loadText(forType: .text)
            case UTType.item.identifier: loadFileURL(forType: .item, DC_MSG_FILE)
            default: continuation.resume(throwing: Error.unknownType)
            }
            func loadFileURL(forType type: UTType, _ viewType: Int32) {
                provider.loadInPlaceFileRepresentation(forTypeIdentifier: type.identifier) { url, _, error in
                    guard let url else {
                        return continuation.resume(throwing: error ?? Error.providerDidNotReturnValueNorError)
                    }
                    NSFileCoordinator().coordinate(readingItemAt: url, error: nil) { url in
                        do {
                            let tempFile = shareExtensionDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension(url.pathExtension)
                            try FileManager.default.copyItem(at: url, to: tempFile)
                            continuation.resume(returning: .contentsAt(url: tempFile, viewType: viewType))
                        } catch {
                            logger.error("Failed to copy file with error \(error)")
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
            func loadText(forType type: UTType) {
                provider.loadItem(forTypeIdentifier: type.identifier) { item, error in
                    if let string = item as? String {
                        continuation.resume(returning: .text(text: string))
                    } else if let url = item as? URL,
                              let data = try? Data(contentsOf: url),
                              let imageFormat = ImageFormat.get(from: data) {
                        // This case adds support for sharing a long-pressed
                        // image in Safari which gives only a url to NSItemProvider
                        do {
                            let localUrl = shareExtensionDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension(imageFormat.rawValue)
                            try data.write(to: localUrl)
                            continuation.resume(returning: .contentsAt(url: localUrl, viewType: DC_MSG_IMAGE))
                        } catch {
                            continuation.resume(returning: .text(text: url.absoluteString))
                        }
                    } else if let url = item as? URL {
                        continuation.resume(returning: .text(text: url.absoluteString))
                    } else {
                        continuation.resume(throwing: error ?? Error.failedToConvertDataToString)
                    }
                }
            }
        }
    }
    
    enum Error: Swift.Error {
        case unknownType
        case failedToConvertDataToString
        /// Should never be called
        case providerDidNotReturnValueNorError
    }
}

/// Helper for using switch with function where each case is sent as argument into the function
private func ~= <T>(value: T, block: (T) -> Bool) -> Bool {
    block(value)
}
