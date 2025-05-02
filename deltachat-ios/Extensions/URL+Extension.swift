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
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else {
           completionHandler?(nil, ConversionError.runtimeError("Could not initiate AVAssertExportSession"))
           return
        }

        let filename = self.deletingPathExtension().lastPathComponent.replacingOccurrences(of: ".", with: "-").appending(".mp4")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
            } catch {
                completionHandler?(nil, error)
            }
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        let start = CMTimeMakeWithSeconds(0.0, preferredTimescale: 0)
        let range = CMTimeRangeMake(start: start, duration: avAsset.duration)
        exportSession.timeRange = range

        exportSession.exportAsynchronously(completionHandler: {
            switch exportSession.status {
            case .failed:
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
