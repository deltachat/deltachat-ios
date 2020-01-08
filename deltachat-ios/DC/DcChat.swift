import Foundation
import UIKit

class DcChat {
    var chatPointer: OpaquePointer?
    var dcContextPointer: OpaquePointer?

    init(dcContextPointer: OpaquePointer, id: Int) {
        if let p = dc_get_chat(dcContextPointer, UInt32(id)) {
            chatPointer = p
            self.dcContextPointer = dcContextPointer
        } else {
            fatalError("Invalid chatID opened \(id)")
        }
    }

    deinit {
        dc_chat_unref(chatPointer)
        dcContextPointer = nil
    }

    var id: Int {
        return Int(dc_chat_get_id(chatPointer))
    }

    var name: String {
        guard let cString = dc_chat_get_name(chatPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    var type: Int {
        return Int(dc_chat_get_type(chatPointer))
    }

    var chatType: ChatType {
        return ChatType(rawValue: type) ?? ChatType.GROUP // group as fallback - shouldn't get here
    }

    var color: UIColor {
        return UIColor(netHex: Int(dc_chat_get_color(chatPointer)))
    }

    var isUnpromoted: Bool {
        return Int(dc_chat_is_unpromoted(chatPointer)) != 0
    }

    var isGroup: Bool {
        let type = Int(dc_chat_get_type(chatPointer))
        return type == DC_CHAT_TYPE_GROUP || type == DC_CHAT_TYPE_VERIFIED_GROUP
    }

    var isSelfTalk: Bool {
        return Int(dc_chat_is_self_talk(chatPointer)) != 0
    }

    var isDeviceTalk: Bool {
        return Int(dc_chat_is_device_talk(chatPointer)) != 0
    }

    var canSend: Bool {
        return Int(dc_chat_can_send(chatPointer)) != 0
    }

    var isVerified: Bool {
        return dc_chat_is_verified(chatPointer) > 0
    }

    var contactIds: [Int] {
        return DcUtils.copyAndFreeArray(inputArray: dc_get_chat_contacts(self.dcContextPointer, UInt32(id)))
    }

    lazy var profileImage: UIImage? = { [unowned self] in
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
                //logger.warning("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
        }()
}
