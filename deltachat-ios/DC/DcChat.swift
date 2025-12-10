import UIKit

/// An object representing a single chat in memory
///
/// See [dc_chat_t Class Reference](https://c.delta.chat/classdc__chat__t.html)
public class DcChat {
    var chatPointer: OpaquePointer?

    // use DcContext.getChat() instead of calling the constructor directly
    public init(chatPointer: OpaquePointer?) {
        self.chatPointer = chatPointer
    }

    deinit {
        dc_chat_unref(chatPointer)
    }

    public var id: Int {
        return Int(dc_chat_get_id(chatPointer))
    }

    public var isValid: Bool {
        return self.chatPointer != nil
    }

    public var name: String {
        guard let cString = dc_chat_get_name(chatPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var color: UIColor {
        return UIColor(netHex: Int(dc_chat_get_color(chatPointer)))
    }

    public var isArchived: Bool {
        return Int(dc_chat_get_visibility(chatPointer)) == DC_CHAT_VISIBILITY_ARCHIVED
    }

    public var visibility: Int32 {
        return dc_chat_get_visibility(chatPointer)
    }

    public var isUnpromoted: Bool {
        return Int(dc_chat_is_unpromoted(chatPointer)) != 0
    }

    public var type: Int {
        return Int(dc_chat_get_type(chatPointer))
    }

    public var isMultiUser: Bool {
        return type != DC_CHAT_TYPE_SINGLE
    }

    public var isMailinglist: Bool {
        return type == DC_CHAT_TYPE_MAILINGLIST
    }

    public var isOutBroadcast: Bool {
        return type == DC_CHAT_TYPE_OUT_BROADCAST
    }

    public var isInBroadcast: Bool {
        return type == DC_CHAT_TYPE_IN_BROADCAST
    }

    public var isSelfTalk: Bool {
        return Int(dc_chat_is_self_talk(chatPointer)) != 0
    }

    public var isDeviceTalk: Bool {
        return Int(dc_chat_is_device_talk(chatPointer)) != 0
    }

    public var isContactRequest: Bool {
        return Int(dc_chat_is_contact_request(chatPointer)) != 0
    }

    public var isEncrypted: Bool {
        return Int(dc_chat_is_encrypted(chatPointer)) != 0
    }

    public var canSend: Bool {
        return Int(dc_chat_can_send(chatPointer)) != 0
    }

    public var isMuted: Bool {
        return dc_chat_is_muted(chatPointer) != 0
    }

    public func getContactIds(_ dcContext: DcContext) -> [Int] {
        return DcUtils.copyAndFreeArray(inputArray: dc_get_chat_contacts(dcContext.contextPointer, UInt32(id)))
    }

    public func getMailinglistAddr() -> String {
        guard let cString = dc_chat_get_mailinglist_addr(chatPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public lazy var profileImage: UIImage? = {
        guard let cString = dc_chat_get_profile_image(chatPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        if path.isFileURL {
            do {
                let data = try Data(contentsOf: path)
                let image = UIImage(data: data)
                return image
            } catch {
                print("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
    }()

    public var profileImageURL: URL? {
        guard let cString = dc_chat_get_profile_image(chatPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        return path
    }

    public var isSendingLocations: Bool {
        return dc_chat_is_sending_locations(chatPointer) == 1
    }
}
