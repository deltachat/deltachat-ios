import UIKit

/// An object representing a single message in memory.
///
/// See [dc_msg_t Class Reference](https://c.delta.chat/classdc__msg__t.html)
public class DcMsg {

    var messagePointer: OpaquePointer?

    init(pointer: OpaquePointer?) {
        messagePointer = pointer
    }

    deinit {
        dc_msg_unref(messagePointer)
    }

    public var cptr: OpaquePointer? {
        return messagePointer
    }

    public lazy var sentDate: Date = {
        Date(timeIntervalSince1970: Double(timestamp))
    }()

    public func formattedSentDate() -> String {
        return DateUtils.getExtendedRelativeTimeSpanString(timeStamp: Double(timestamp))
    }

    public var isForwarded: Bool {
        return dc_msg_is_forwarded(messagePointer) != 0
    }

    public var isEdited: Bool {
        return dc_msg_is_edited(messagePointer) != 0
    }

    public var isValid: Bool {
        return messagePointer != nil
    }

    public var messageId: String {
        return "\(id)"
    }

    public var id: Int {
        return Int(dc_msg_get_id(messagePointer))
    }

    public var fromContactId: Int {
        return Int(dc_msg_get_from_id(messagePointer))
    }

    public var isMarkerOrInfo: Bool {
        return id == DC_MSG_ID_MARKER1 || id == DC_MSG_ID_DAYMARKER || isInfo
    }

    public var canSave: Bool {
        return !isMarkerOrInfo // info-messages out of context are confusing, see #2567
    }

    public var originalMessageId: Int {
        return Int(dc_msg_get_original_msg_id(messagePointer))
    }

    public var savedMessageId: Int {
        return Int(dc_msg_get_saved_msg_id(messagePointer))
    }

    public var isFromCurrentSender: Bool {
        return fromContactId == DC_CONTACT_ID_SELF
    }

    public var chatId: Int {
        return Int(dc_msg_get_chat_id(messagePointer))
    }

    public var overrideSenderName: String? {
        guard let cString = dc_msg_get_override_sender_name(messagePointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func getSenderName(_ dcContact: DcContact, markOverride: Bool = false) -> String {
        if let overrideName = overrideSenderName {
            return (markOverride ? "~" : "") + overrideName
        } else {
            return dcContact.displayName
        }
    }

    public var text: String? {
        get {
            guard let cString = dc_msg_get_text(messagePointer) else { return nil }
            let swiftString = String(cString: cString)
            dc_str_unref(cString)
            return swiftString
        }
        set {
            if let newValue = newValue {
                dc_msg_set_text(messagePointer, newValue.cString(using: .utf8))
            } else {
                dc_msg_set_text(messagePointer, nil)
            }
        }
    }

    public var hasText: Bool {
        return !(text ?? "").isEmpty
    }

    public var subject: String {
        guard let cString = dc_msg_get_subject(messagePointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var quoteText: String? {
        guard let cString = dc_msg_get_quoted_text(messagePointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var quoteMessage: DcMsg? {
        get {
            guard let msgpointer = dc_msg_get_quoted_msg(messagePointer) else { return nil }
            return DcMsg(pointer: msgpointer)
        }
        set {
            dc_msg_set_quote(messagePointer, newValue?.messagePointer)
        }
    }

    public var isReplyToSelf: Bool {
        if let quoteMessage {
            return quoteMessage.isFromCurrentSender
        } else {
            return false
        }
    }

    public var parent: DcMsg? {
        guard let msgpointer = dc_msg_get_parent(messagePointer) else { return nil }
        return DcMsg(pointer: msgpointer)
    }

    public var downloadState: Int32 {
        return dc_msg_get_download_state(messagePointer)
    }

    public var fileURL: URL? {
        if let file {
            return URL(fileURLWithPath: file, isDirectory: false)
        }
        return nil
    }

    public lazy var image: UIImage? = {
        let filetype = dc_msg_get_viewtype(messagePointer)
        if let path = fileURL, filetype == DC_MSG_IMAGE || filetype == DC_MSG_GIF || filetype == DC_MSG_STICKER {
            if path.isFileURL {
                do {
                    let data = try Data(contentsOf: path)
                    let image = UIImage(data: data)
                    return image
                } catch {
                    print("failed to load image: \(path), \(error)")
                    return nil
                }
            }
            return nil
        } else {
            return nil
        }
    }()

    public func getWebxdcBlob(filename: String) -> Data {
        let ptrSize = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            ptrSize.deallocate()
        }

        guard let ccharPtr = dc_msg_get_webxdc_blob(messagePointer, filename, ptrSize) else {
            return Data()
        }
        defer {
            dc_str_unref(ccharPtr)
        }

        let count = ptrSize.pointee
        let buffer = UnsafeBufferPointer<Int8>(start: ccharPtr, count: count)
        let data = Data(buffer: buffer)
        return data
    }

    public func getWebxdcInfoJson() -> String {
        guard let cString = dc_msg_get_webxdc_info(messagePointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func getWebxdcInfoDict() -> [String: AnyObject] {
        let jsonString = self.getWebxdcInfoJson()
        if let data: Data = jsonString.data(using: .utf8),
           let infoDict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: AnyObject] {
               return infoDict
           }
        return [:]
    }

    // returns webxdc app name for an webxdc-info-messages or webxdc-instances
    public func getWebxdcAppName() -> String {
        let msg = if self.isInfo, let parent = self.parent {
            parent
        } else {
            self
        }
        let dict = msg.getWebxdcInfoDict()
        return dict["name"] as? String ?? "ErrName"
    }

    public func getWebxdcHref() -> String? {
        guard let cString = dc_msg_get_webxdc_href(messagePointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var messageHeight: CGFloat {
        return CGFloat(dc_msg_get_height(messagePointer))
    }

    public var messageWidth: CGFloat {
        return CGFloat(dc_msg_get_width(messagePointer))
    }

    public var duration: Int {
        return Int(dc_msg_get_duration(messagePointer))
    }

    public func setLateFilingMediaSize(width: CGFloat, height: CGFloat, duration: Int) {
        dc_msg_latefiling_mediasize(messagePointer, Int32(width), Int32(height), Int32(duration))
    }

    public var file: String? {
        if let cString = dc_msg_get_file(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    public var filemime: String? {
        if let cString = dc_msg_get_filemime(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    public var isUnsupportedMediaFile: Bool {
        return filemime == "audio/ogg"
    }

    public var filename: String? {
        if let cString = dc_msg_get_filename(messagePointer) {
            let str = String(cString: cString)
            dc_str_unref(cString)
            return str.isEmpty ? nil : str
        }

        return nil
    }

    public func setFile(filepath: String?, fileName: String? = nil, mimeType: String? = nil) {
        dc_msg_set_file_and_deduplicate(messagePointer, filepath, fileName, mimeType)
    }

    public func setDimension(width: CGFloat, height: CGFloat) {
        dc_msg_set_dimension(messagePointer, Int32(width), Int32(height))
    }

    public var filesize: Int {
        return Int(dc_msg_get_filebytes(messagePointer))
    }

    // DC_MSG_*
    public var type: Int32 {
        return dc_msg_get_viewtype(messagePointer)
    }

    // DC_STATE_*
    public var state: Int {
        return Int(dc_msg_get_state(messagePointer))
    }

    public var timestamp: Int64 {
        return Int64(dc_msg_get_timestamp(messagePointer))
    }

    public var isInfo: Bool {
        return dc_msg_is_info(messagePointer) == 1
    }

    public var infoType: Int32 {
        return dc_msg_get_info_type(messagePointer)
    }

    public var infoContactId: Int? {
        let id = Int(dc_msg_get_info_contact_id(messagePointer))
        return id == 0 ? nil : id
    }

    public var hasHtml: Bool {
        return dc_msg_has_html(messagePointer) == 1
    }

    public var hasLocation: Bool {
        return dc_msg_has_location(messagePointer) == 1
    }

    public func summary(chars: Int) -> String? {
        guard let cString = dc_msg_get_summarytext(messagePointer, Int32(chars)) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public func summary(chat: DcChat) -> DcLot {
        guard let chatPointer = chat.chatPointer else {
            return DcLot(nil)
        }
        guard let dcLotPointer = dc_msg_get_summary(messagePointer, chatPointer) else {
            return DcLot(nil)
        }
        return DcLot(dcLotPointer)
    }

    public func showEnvelope() -> Bool {
        return dc_msg_get_showpadlock(messagePointer) == 0 && downloadState == DC_DOWNLOAD_DONE
    }
}
