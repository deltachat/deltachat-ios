import Foundation
import DcCore
import UIKit
import AVFoundation

extension DcMsg: MessageType {
    
    public var sender: SenderType {
        return Sender(id: "\(fromContactId)", displayName: fromContact.displayName)
    }

    public var kind: MessageKind {
        if isInfo {
            let text = NSAttributedString(string: self.text ?? "", attributes: [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: DcColors.grayTextColor,
                ])
            return MessageKind.info(text)
        } else if isSetupMessage {
            return MessageKind.text(String.localized("autocrypt_asm_click_body"))
        }

        let text = self.text ?? ""

        if self.viewtype == nil {
            return MessageKind.text(text)
        }

        switch self.viewtype! {
        case .image:
            return createImageMessage(text: text)
        case .video:
            return createVideoMessage(text: text)
        case .voice, .audio:
            return createAudioMessage(text: text)
        case .gif:
            return createAnimatedImageMessage(text: text)
        default:
            // TODO: custom views for audio, etc
            if self.filename != nil {
                if Utils.hasAudioSuffix(url: fileURL!) {
                   return createAudioMessage(text: text)
                }
                return createFileMessage(text: text)
            }
            return MessageKind.text(text)
        }
    }

    internal func createVideoMessage(text: String) -> MessageKind {
        if text.isEmpty {
            var thumbnail: UIImage?
            if let fileURL = fileURL {
                thumbnail = ThumbnailCache.shared.restoreImage(key: fileURL.absoluteString)
            }
            return MessageKind.video(Media(url: fileURL, image: thumbnail))
        }
        let attributedString = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
            NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor]
        )
        return MessageKind.videoText(Media(url: fileURL, text: [attributedString]))
    }

    internal func createImageMessage(text: String) -> MessageKind {
        if text.isEmpty {
            return MessageKind.photo(Media(image: image))
        }
        let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
                                                                             NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        return MessageKind.photoText(Media(image: image, text: [attributedString]))
    }

    internal func createAnimatedImageMessage(text: String) -> MessageKind {
        if text.isEmpty {
            return MessageKind.animatedImageText(Media(url: fileURL, image: image))
        }
        let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
                                                                             NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        return MessageKind.animatedImageText(Media(url: fileURL, image: image, text: [attributedString]))
    }

    internal func createAudioMessage(text: String) -> MessageKind {
        let audioAsset = AVURLAsset(url: fileURL!)
        let seconds = Float(CMTimeGetSeconds(audioAsset.duration))
        if !text.isEmpty {
            let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
                                                                                 NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
            return MessageKind.audio(Audio(url: audioAsset.url, duration: seconds, text: attributedString))
        }
        return MessageKind.audio(Audio(url: fileURL!, duration: seconds))
    }

    internal func createFileMessage(text: String) -> MessageKind {
        let fileString = "\(self.filename ?? "???")"
        let fileSizeString = getPrettyFileSize()
        let attributedMediaMessageString =
                   NSAttributedString(string: text,
                                             attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
                                                          NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        let attributedFileString = NSAttributedString(string: fileString,
                                                             attributes: [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 13.0),
                                                                          NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        let attributedFileSizeString = NSAttributedString(string: fileSizeString,
                                                                 attributes: [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 13.0),
                                                                              NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])

        let mediaText = [attributedMediaMessageString, attributedFileString, attributedFileSizeString]
        return MessageKind.fileText(Media(url: fileURL, placeholderImage: UIImage(named: "ic_attach_file_36pt"), text: mediaText))
    }

    private func getPrettyFileSize() -> String {
        if self.filesize <= 0 { return "0 B" }
        let units: [String] = ["B", "kB", "MB"]
        let digitGroups = Int(log10(Double(self.filesize)) / log10(1024))
        let size = String(format: "%.1f", Double(filesize) / pow(1024, Double(digitGroups)))
        return "\(size) \(units[digitGroups])"
    }
}
