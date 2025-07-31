import UIKit

/// An object representing a single contact in memory.
///
/// See [dc_contact_t Class Reference](https://c.delta.chat/classdc__contact__t.html)
public class DcContact {
    private var contactPointer: OpaquePointer?

    public init(contactPointer: OpaquePointer?) {
        self.contactPointer = contactPointer
    }

    deinit {
        dc_contact_unref(contactPointer)
    }

    public var displayName: String {
        guard let cString = dc_contact_get_display_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var editedName: String {
        guard let cString = dc_contact_get_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var authName: String {
        guard let cString = dc_contact_get_auth_name(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var email: String {
        guard let cString = dc_contact_get_addr(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var lastSeen: Int64 {
        return Int64(dc_contact_get_last_seen(contactPointer))
    }

    public var wasSeenRecently: Bool {
        return dc_contact_was_seen_recently(contactPointer) == 1
    }

    public var status: String {
        guard let cString = dc_contact_get_status(contactPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var isKeyContact: Bool {
        return dc_contact_is_key_contact(contactPointer) == 1
    }

    public var isVerified: Bool {
        return dc_contact_is_verified(contactPointer) > 0
    }

    public func getVerifierId() -> Int {
        return Int(dc_contact_get_verifier_id(contactPointer))
    }

    public var isBot: Bool {
        return dc_contact_is_bot(contactPointer) != 0
    }

    public var isBlocked: Bool {
        return dc_contact_is_blocked(contactPointer) == 1
    }

    public lazy var profileImage: UIImage? = {
        guard let cString = dc_contact_get_profile_image(contactPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        let path: URL = URL(fileURLWithPath: filename, isDirectory: false)
        if path.isFileURL {
            do {
                let data = try Data(contentsOf: path)
                return UIImage(data: data)
            } catch {
                print("failed to load image: \(filename), \(error)")
                return nil
            }
        }
        return nil
    }()

    public var profileImageURL: URL? {
        guard let cString = dc_contact_get_profile_image(contactPointer) else { return nil }
        let filename = String(cString: cString)
        dc_str_unref(cString)
        return URL(fileURLWithPath: filename, isDirectory: false)
    }

    public var color: UIColor {
        return UIColor(netHex: Int(dc_contact_get_color(contactPointer)))
    }

    public var id: Int {
        return Int(dc_contact_get_id(contactPointer))
    }
}
