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
        default:
            // TODO: custom views for audio, etc
            if let filename = self.filename {
                if Utils.hasAudioSuffix(url: fileURL!) {
                   return createAudioMessage(text: text)
                }
                return createFileMessage(text: text)
            }
            return MessageKind.text(text)
        }
    }

    internal func createVideoMessage(text: String) -> MessageKind {
        let thumbnail = Utils.generateThumbnailFromVideo(url: fileURL)
        if text.isEmpty {
            return MessageKind.video(Media(url: fileURL, image: thumbnail))
        }
        let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                             NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        return MessageKind.videoText(Media(url: fileURL, image: thumbnail, text: attributedString))
    }

    internal func createImageMessage(text: String) -> MessageKind {
        if text.isEmpty {
            return MessageKind.photo(Media(image: image))
        }
        let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                             NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        return MessageKind.photoText(Media(image: image, text: attributedString))
    }

    internal func createAudioMessage(text: String) -> MessageKind {
        let audioAsset = AVURLAsset(url: fileURL!)
        let seconds = Float(CMTimeGetSeconds(audioAsset.duration))
        if !text.isEmpty {
            let attributedString = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                                 NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
            return MessageKind.audio(Audio(url: audioAsset.url, duration: seconds, text: attributedString))
        }
        return MessageKind.audio(Audio(url: fileURL!, duration: seconds))
    }

    internal func createFileMessage(text: String) -> MessageKind {
        let fileString = "\(self.filename ?? "???") (\(self.filesize / 1024) kB)"
        let attributedFileString = NSMutableAttributedString(string: fileString,
                                                             attributes: [NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 13.0),
                                                                          NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor])
        if !text.isEmpty {
            attributedFileString.append(NSAttributedString(string: "\n\n",
                                                           attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 7.0)]))
            attributedFileString.append(NSAttributedString(string: text,
                                                           attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16.0),
                                                                        NSAttributedString.Key.foregroundColor: DcColors.defaultTextColor]))
        }
        return MessageKind.fileText(Media(text: attributedFileString))
    }

    
}
