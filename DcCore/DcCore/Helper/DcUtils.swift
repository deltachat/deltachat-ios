import Foundation
import UIKit
import MobileCoreServices
import AVFoundation
import Intents

public struct DcUtils {

    public static func getInitials(inputName: String) -> String {
        if let firstLetter = inputName.first {
            return firstLetter.uppercased()
        } else {
            return ""
        }
    }

    public static func donateSendMessageIntent(chatId: Int) {
       let chat = DcContext.shared.getChat(chatId: chatId)
       let groupName = INSpeakableString(spokenPhrase: chat.name)

       let sendMessageIntent = INSendMessageIntent(recipients: nil,
                                                   content: nil,
                                                   speakableGroupName: groupName,
                                                   conversationIdentifier: "\(chat.id)",
                                                   serviceName: nil,
                                                   sender: nil)

       // Add the user's avatar to the intent.
        if #available(iOS 12.0, *) {
            if let imageData = chat.profileImage?.pngData() {
                let image = INImage(imageData: imageData)
                sendMessageIntent.setImage(image, forParameterNamed: \.speakableGroupName)
            }
        }

       // Donate the intent.
       let interaction = INInteraction(intent: sendMessageIntent, response: nil)
       interaction.donate(completion: { error in
           if error != nil {
               // Add error handling here.
                DcContext.shared.logger?.error(error.debugDescription)
           } else {
               // Do something, e.g. send the content to a contact.
                DcContext.shared.logger?.debug("donated message intent")
           }
       })
    }

    static func copyAndFreeArray(inputArray: OpaquePointer?) -> [Int] {
        var acc: [Int] = []
        let len = dc_array_get_cnt(inputArray)
        for i in 0 ..< len {
            let e = dc_array_get_id(inputArray, i)
            acc.append(Int(e))
        }
        dc_array_unref(inputArray)

        return acc
    }

    static func copyAndFreeArrayWithLen(inputArray: OpaquePointer?, len: Int = 0) -> [Int] {
        var acc: [Int] = []
        let arrayLen = dc_array_get_cnt(inputArray)
        let start = max(0, arrayLen - len)
        for i in start ..< arrayLen {
            let e = dc_array_get_id(inputArray, i)
            acc.append(Int(e))
        }
        dc_array_unref(inputArray)

        return acc
    }

    static func copyAndFreeArrayWithOffset(inputArray: OpaquePointer?, len: Int = 0, from: Int = 0, skipEnd: Int = 0) -> [Int] {
        let lenArray = dc_array_get_cnt(inputArray)
        if lenArray <= skipEnd || lenArray == 0 {
            dc_array_unref(inputArray)
            return []
        }

        let start = lenArray - 1 - skipEnd
        let end = max(0, start - len)
        let finalLen = start - end + (len > 0 ? 0 : 1)
        var acc: [Int] = [Int](repeating: 0, count: finalLen)

        for i in stride(from: start, to: end, by: -1) {
            let index = finalLen - (start - i) - 1
            acc[index] = Int(dc_array_get_id(inputArray, i))
        }

        dc_array_unref(inputArray)
        DcContext.shared.logger?.info("got: \(from) \(len) \(lenArray) - \(acc)")

        return acc
    }

    public static func saveImage(image: UIImage) -> String? {
        let suffix = image.isTransparent() ? "png" : "jpg"
        guard let data = image.isTransparent() ? image.pngData() : image.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        return saveImage(data: data, suffix: suffix)
    }

    public static func saveImage(data: Data, suffix: String) -> String? {
        let timestamp = Double(Date().timeIntervalSince1970)
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: false) as NSURL,
            let path = directory.appendingPathComponent("\(timestamp).\(suffix)")
            else { return nil }

        do {
            try data.write(to: path)
            return path.relativePath
        } catch {
            DcContext.shared.logger?.info(error.localizedDescription)
            return nil
        }
    }

    public static func getMimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension

        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }

    public static func generateThumbnailFromVideo(url: URL?) -> UIImage? {
		guard let url = url else {
			return nil
		}
		do {
			let asset = AVURLAsset(url: url)
			let imageGenerator = AVAssetImageGenerator(asset: asset)
			imageGenerator.appliesPreferredTrackTransform = true
			let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
			return UIImage(cgImage: cgImage)
		} catch {
			print(error.localizedDescription)
			return nil
		}
	}

	public static func thumbnailFromPdf(withUrl url:URL, pageNumber:Int = 1, width: CGFloat = 240) -> UIImage? {
		guard let pdf = CGPDFDocument(url as CFURL),
			let page = pdf.page(at: pageNumber)
			else {
				return nil
		}

		var pageRect = page.getBoxRect(.mediaBox)
		let pdfScale = width / pageRect.size.width
		pageRect.size = CGSize(width: pageRect.size.width*pdfScale, height: pageRect.size.height*pdfScale)
		pageRect.origin = .zero

		UIGraphicsBeginImageContext(pageRect.size)
		let context = UIGraphicsGetCurrentContext()!

		// White BG
		context.setFillColor(UIColor.white.cgColor)
		context.fill(pageRect)
		context.saveGState()

		// Next 3 lines makes the rotations so that the page look in the right direction
		context.translateBy(x: 0.0, y: pageRect.size.height)
		context.scaleBy(x: 1.0, y: -1.0)
		context.concatenate(page.getDrawingTransform(.mediaBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))

		context.drawPDFPage(page)
		context.restoreGState()

		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image
	}

}
