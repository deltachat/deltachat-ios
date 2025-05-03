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

    public func convertToMp4(completionHandler: ((URL?, Error?) -> Void)?) {
        let avAsset = AVURLAsset(url: self, options: nil)
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetMediumQuality) else {
           completionHandler?(nil, ConversionError.runtimeError("Could not initiate AVAssertExportSession"))
           return
        }

        let filename = self.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ".", with: "-").appending(".mp4")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        FileHelper.deleteFile(atPath: outputURL.path)

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.exportAsynchronously(completionHandler: {
            switch exportSession.status {
            case .failed:
                let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)
                logger.info("convertToMp4: compatible presets: \(compatiblePresets)")
                logger.info("convertToMp4: supported file types: \(exportSession.supportedFileTypes)")
                completionHandler?(nil, exportSession.error)
            case .cancelled:
                completionHandler?(nil, nil)
            case .completed:
                completionHandler?(exportSession.outputURL, nil)
            default: break
            }
        })
    }
}
