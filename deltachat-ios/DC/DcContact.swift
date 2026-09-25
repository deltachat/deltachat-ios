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

    public var freshness: Int32 {
        return dc_contact_get_freshness(contactPointer)
    }

    public func getSubtitle(oldOnly: Bool) -> String? {
        if id == DC_CONTACT_ID_SELF || id == DC_CONTACT_ID_DEVICE {
            return nil
        } else if isBlocked {
            return String.localized("contact_blocked")
        } else if !isKeyContact {
            return email
        } else if isBot {
            return String.localized("bot")
        } else if freshness == DC_FRESHNESS_RECENTLY_SEEN {
            return String.localized("seen_recently")
        } else if oldOnly && freshness != DC_FRESHNESS_OLD {
            return nil
        }
        return formattedLastSeen
    }

    private var formattedLastSeen: String? {
        if lastSeen == 0 {
            return String.localized("never_seen")
        }

        let lastSeenDate = Date(timeIntervalSince1970: TimeInterval(lastSeen))
        if Calendar.current.isDateInToday(lastSeenDate) {
            return String.localized("seen_today")
        } else if Calendar.current.isDateInYesterday(lastSeenDate) {
            return String.localized("seen_yesterday")
        }

        let age = Date().timeIntervalSince(lastSeenDate)
        let oneWeek: TimeInterval = 7 * 24 * 60 * 60
        let oneMonth: TimeInterval = 31 * 24 * 60 * 60
        let oneYear: TimeInterval = 365 * 24 * 60 * 60
        if age < oneWeek {
            return String.localized("seen_within_week")
        } else if age < oneMonth {
            return String.localized("seen_within_month")
        } else if age < oneYear {
            return String.localized(stringID: "seen_n_months_ago", parameter: Int(age / oneMonth))
        }

        return String.localized(stringID: "seen_n_years_ago", parameter: Int(age / oneYear))
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
