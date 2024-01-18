import Foundation

/// An object containing a set of values.
///
/// See [dc_lot_t Class Reference](https://c.delta.chat/classdc__lot__t.html)
public class DcLot {
    private var dcLotPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(_ dcLotPointer: OpaquePointer?) {
        self.dcLotPointer = dcLotPointer
    }

    deinit {
        dc_lot_unref(dcLotPointer)
    }

    public var text1: String? {
        guard let cString = dc_lot_get_text1(dcLotPointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var text1Meaning: Int {
        return Int(dc_lot_get_text1_meaning(dcLotPointer))
    }

    public var text2: String? {
        guard let cString = dc_lot_get_text2(dcLotPointer) else { return nil }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var timestamp: Int64 {
        return Int64(dc_lot_get_timestamp(dcLotPointer))
    }

    public var state: Int {
        return Int(dc_lot_get_state(dcLotPointer))
    }

    public var id: Int {
        return Int(dc_lot_get_id(dcLotPointer))
    }
}
