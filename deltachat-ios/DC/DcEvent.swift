import Foundation

/// Opaque object describing a single event.
///
/// See [dc_event_t Class Reference](https://c.delta.chat/classdc__event__t.html)
public class DcEvent {
    private var eventPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(eventPointer: OpaquePointer?) {
        self.eventPointer = eventPointer
    }

    deinit {
        dc_event_unref(eventPointer)
    }

    public var accountId: Int {
        return Int(dc_event_get_account_id(eventPointer))
    }

    public var id: Int32 {
        return Int32(dc_event_get_id(eventPointer))
    }

    public var data1Int: Int {
        return Int(dc_event_get_data1_int(eventPointer))
    }

    public var data2Int: Int {
        return Int(dc_event_get_data2_int(eventPointer))
    }

    public var data2String: String {
        guard let cString = dc_event_get_data2_str(eventPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var data2Data: Data {
        guard let cPtr = dc_event_get_data2_str(eventPointer) else { return Data() }
        let data = Data(bytes: cPtr, count: data2Int)
        dc_str_unref(cPtr)
        return data
    }
}
