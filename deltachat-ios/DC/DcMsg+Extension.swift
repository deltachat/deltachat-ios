import Foundation
import DcCore
import UIKit
import AVFoundation

extension DcMsg {
    public func getPrettyFileSize() -> String {
        if self.filesize <= 0 { return "0 B" }
        let units: [String] = ["B", "kB", "MB"]
        let digitGroups = Int(log10(Double(self.filesize)) / log10(1024))
        let size = String(format: "%.1f", Double(filesize) / pow(1024, Double(digitGroups)))
        return "\(size) \(units[digitGroups])"
    }

    public func getWebxdcInfoDict() -> [String: AnyObject] {
        let jsonString = self.getWebxdcInfoJson()
        if let data: Data = jsonString.data(using: .utf8),
           let infoDict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: AnyObject] {
               return infoDict
           }
        return [:]
    }

    public func getWebxdcName() -> String? {
        if let title = getWebxdcInfoDict()["name"] as? String {
            return title
        }
        return nil
    }

    public func getWebxdcIcon() -> UIImage? {
        if let iconfilePath = getWebxdcInfoDict()["icon"] as? String {
            let blob = getWebxdcBlob(filename: iconfilePath)
            if !blob.isEmpty {
                return UIImage(data: blob)
            }
        }
        return nil
    }

    public func getWebxdcSummary() -> String {
        if let summary = getWebxdcInfoDict()["summary"] as? String {
            return summary
        }
        return "Webxdc"
    }
}
