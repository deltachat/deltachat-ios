import Foundation
import UIKit
import UniformTypeIdentifiers

public var shareExtensionDirectory = FileManager.default
    .containerURL(forSecurityApplicationGroupIdentifier: DatabaseHelper.applicationGroupIdentifier)!
    .appendingPathComponent("share_extension", isDirectory: true)

/// An NSItemProvider wrapper that can be encoded and sent between extensions and main app process
public enum CodableNSItemProvider: Codable, Equatable {
    case contentsAt(url: URL, viewType: Int32)
    case text(text: String)

    public var viewType: Int32 {
        switch self {
        case .contentsAt(_, let viewType): return viewType
        case .text: return DC_MSG_TEXT
        }
    }

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
    
    public init(from provider: NSItemProvider, in directory: URL) async throws {
        self = try await withCheckedThrowingContinuation { continuation in
            switch provider.hasItemConformingToTypeIdentifier {
            case UTType.gif.identifier: loadFile(forType: .gif, DC_MSG_GIF, plistToImage: true)
            case UTType.webP.identifier: loadFile(forType: .webP, DC_MSG_IMAGE, plistToImage: true)
            case UTType.png.identifier: loadFile(forType: .png, DC_MSG_IMAGE, plistToImage: true)
            case UTType.jpeg.identifier: loadFile(forType: .jpeg, DC_MSG_IMAGE, plistToImage: true)
            case UTType.image.identifier: loadFile(forType: .image, DC_MSG_IMAGE, plistToImage: true)
            case UTType.mpeg4Movie.identifier: loadFile(forType: .mpeg4Movie, DC_MSG_VIDEO)
            case UTType.quickTimeMovie.identifier: loadFile(forType: .quickTimeMovie, DC_MSG_VIDEO)
            case UTType.movie.identifier: loadFile(forType: .movie, DC_MSG_VIDEO)
            case UTType.video.identifier: loadFile(forType: .video, DC_MSG_VIDEO)
            case UTType.fileURL.identifier: loadFileURL()
            case UTType.url.identifier: loadImageAtUrlOrUrlAsText()
            case UTType.plainText.identifier: loadText()
            case UTType.text.identifier: loadText()
            case UTType.item.identifier: loadFile(forType: .item, DC_MSG_FILE)
            default: continuation.resume(throwing: Error.unknownType)
            }
            func loadFileURL() {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url {
                        do {
                            let tempFile = directory.appendingPathComponent(url.lastPathComponent)
                            try FileManager.default.copyItem(at: url, to: tempFile)
                            let viewType = url.pathExtension == "xdc" ? DC_MSG_WEBXDC : DC_MSG_FILE
                            return continuation.resume(returning: .contentsAt(url: tempFile, viewType: viewType))
                        } catch {
                            logger.error("Failed to copy file from fileUrl with error \(error)")
                        }
                    }
                    // Fallback in case we could not load the url or access the file at the location of the url
                    if provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                        loadFile(forType: .item, DC_MSG_FILE)
                    } else {
                        loadText()
                    }
                }
            }
            func loadFile(forType type: UTType, _ viewType: Int32, plistToImage: Bool = false) {
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                    guard let url else {
                        return continuation.resume(throwing: error ?? Error.providerDidNotReturnValueNorError)
                    }
                    let tempFile = directory.appendingPathComponent(url.lastPathComponent)
                    do {
                        // If an app shares a UIImage instead of a path (eg the native screenshot process)
                        // the file we receive is a PList so we need to load the UIImage differently.
                        if plistToImage, url.isBplist() {
                            let data = try Data(contentsOf: url)
                            let image = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIImage.self, from: data)
                            if let pngData = image?.pngData() {
                                try pngData.write(to: tempFile)
                                continuation.resume(returning: .contentsAt(url: tempFile, viewType: viewType))
                            } else {
                                throw Error.loadingImageFailed
                            }
                        } else {
                            try FileManager.default.copyItem(at: url, to: tempFile)
                            let viewType = url.pathExtension == "xdc" ? DC_MSG_WEBXDC : viewType
                            continuation.resume(returning: .contentsAt(url: tempFile, viewType: viewType))
                        }
                    } catch {
                        logger.error("Failed to copy file with error \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            func loadImageAtUrlOrUrlAsText() {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    // This adds support for sharing a long-pressed
                    // image in Safari which gives only a url to NSItemProvider
                    if let url, let data = try? Data(contentsOf: url), let imageFormat = ImageFormat.get(from: data) {
                        do {
                            let localUrl = directory.appendingPathComponent(url.lastPathComponent)
                            try data.write(to: localUrl)
                            continuation.resume(returning: .contentsAt(url: localUrl, viewType: imageFormat == .gif ? DC_MSG_GIF : DC_MSG_IMAGE))
                        } catch {
                            continuation.resume(returning: .text(text: url.absoluteString))
                        }
                    } else {
                        loadText()
                    }
                }
            }
            func loadText() {
                _ = provider.loadObject(ofClass: String.self) { string, error in
                    if let string {
                        continuation.resume(returning: .text(text: string))
                    } else {
                        continuation.resume(throwing: error ?? Error.loadingStringFailed)
                    }
                }
            }
        }
    }
    
    enum Error: Swift.Error {
        case unknownType
        case loadingStringFailed
        case loadingImageFailed
        /// Should never be called
        case providerDidNotReturnValueNorError
    }
}

/// Helper for using switch with function where each case is sent as argument into the function
private func ~= <T>(value: T, block: (T) -> Bool) -> Bool {
    block(value)
}

private extension URL {
    func isBplist() -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: self) else { return false }
        let data = handle.readData(ofLength: 6)
        return data == Data("bplist".utf8)
    }
}
