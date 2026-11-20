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

    public static func donateSendMessageIntent(context: DcContext, chatId: Int, chatAvatar: UIImage?) {
        let chat = context.getChat(chatId: chatId)
        let intent = INSendMessageIntent(forChat: chat, msg: nil)
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.groupIdentifier = "\(context.id)"
        interaction.donate(completion: { error in
            if error != nil {
                logger.error(error.debugDescription)
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

    public static func getConnectivityString(dcContext: DcContext, connectedString: String) -> String {
        let connectivity = dcContext.getConnectivity()
        if connectivity >= DC_CONNECTIVITY_CONNECTED {
            return connectedString
        } else if connectivity >= DC_CONNECTIVITY_WORKING {
            return String.localized("connectivity_updating")
        } else if connectivity >= DC_CONNECTIVITY_CONNECTING {
          return String.localized("connectivity_connecting")
        } else if UserDefaults.nseFetching {
          return String.localized("connectivity_updating")
        } else {
          return String.localized("connectivity_not_connected")
        }
    }

    public static func showRecentlySeen(context: DcContext, chat: DcChat) -> Bool {
        var recentlySeen = false
        if !chat.isSelfTalk && !chat.isMultiUser && !chat.isMailinglist && !chat.isDeviceTalk {
            let contactIds = chat.getContactIds()
            if contactIds.count == 1 {
                recentlySeen = context.getContact(id: contactIds[0]).freshness == DC_FRESHNESS_RECENTLY_SEEN
            }
        }
        return recentlySeen
    }
}

extension INSendMessageIntent {
    convenience init(forChat dcChat: DcChat, msg: DcMsg?) {
        let dcContext = dcChat.dcContext
        let sender = (msg?.fromContactId).map(dcContext.getContact)
        let overrideSenderName = sender.flatMap { msg?.getSenderName($0, markOverride: true) }
        self.init(
            recipients: dcChat.isMultiUser ? dcChat.getContacts().map {
                INPerson(forContact: $0, dcContext: dcContext)
            }.compactMap(\.self) : nil,
            outgoingMessageType: .outgoingMessageText,
            content: nil,
            speakableGroupName: dcChat.isMultiUser ? INSpeakableString(spokenPhrase: dcChat.name) : nil,
            conversationIdentifier: "\(dcContext.id).\(dcChat.id)",
            serviceName: nil,
            sender: sender.map { INPerson(forContact: $0, name: overrideSenderName, dcContext: dcContext) },
            attachments: nil
        )
        dcChat.profileImage?.pngData().map(setGroupImage)
    }

    /// There is a compiler bug that causes this to crash at runtime when the keypath is defined inside the convenience init block.
    /// Using it from a function like this works. See similar https://developer.apple.com/forums/thread/115786
    func setGroupImage(_ imageData: Data) {
        setImage(INImage(imageData: imageData), forParameterNamed: \.speakableGroupName)
    }
}

extension INPerson {
    convenience init(forContact dcContact: DcContact, name: String? = nil, dcContext: DcContext) {
        self.init(
            personHandle: INPersonHandle(value: "\(dcContext.id)-\(dcContact.id)", type: .unknown),
            nameComponents: nil,
            displayName: name ?? dcContact.displayName,
            image: dcContact.profileImage?.pngData().flatMap(INImage.init(imageData:)),
            contactIdentifier: nil,
            customIdentifier: nil,
            isMe: dcContact.id == DC_CONTACT_ID_SELF
        )
    }
}
