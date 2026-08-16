import Foundation
import AVKit

extension URL {
    enum ConversionError: Error {
        case runtimeError(String)
    }

    public var queryParameters: [String: String]? {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
    }

    var isHTTPURL: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http"
    }

    func hasSameOrigin(as other: URL) -> Bool {
        scheme?.lowercased() == other.scheme?.lowercased()
            && host?.lowercased() == other.host?.lowercased()
            && port == other.port
    }

    /// Note: This copies the file at URL to a temporary file in case the original is deleted (or access is lost) during conversion.
    public func convertToMp4(completionHandler: ((URL?, Error?) -> Void)?) {
        let filename = self.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ".", with: "-")
        let original = filename.appending("." + pathExtension)
        let inputURL = FileHelper.copyIfPossible(src: self, dest: .temporaryDirectory.appendingPathComponent(original))
        let compressed = filename.appending("_compressed.mp4")
        let outputURL = URL.temporaryDirectory.appendingPathComponent(compressed)
        FileHelper.deleteFile(outputURL.path)
        
        let avAsset = AVURLAsset(url: inputURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetMediumQuality) else {
           completionHandler?(nil, ConversionError.runtimeError("Could not initiate AVAssertExportSession"))
           return
        }
        exportSession.timeRange = CMTimeRange(start: .zero, duration: avAsset.duration)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.exportAsynchronously(completionHandler: {
            switch exportSession.status {
            case .failed:
                let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)
                logger.info("convertToMp4: timerange: \(exportSession.timeRange)")
                logger.info("convertToMp4: compatible presets: \(compatiblePresets)")
                logger.info("convertToMp4: supported file types: \(exportSession.supportedFileTypes)")
                logger.info("convertToMp4: error: \(String(describing: exportSession.error)))")
                completionHandler?(nil, exportSession.error)
            case .cancelled:
                completionHandler?(nil, nil)
            case .completed:
                completionHandler?(exportSession.outputURL, nil)
            default: break
            }
        })
    }

    /// This makes URL.temporaryDirectory available pre iOS 16
    @_disfavoredOverload public static var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    /// This makes URL.cachesDirectory available pre iOS 16
    @_disfavoredOverload public static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "")
    }
}
