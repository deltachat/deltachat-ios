import Foundation

/// An object containing a simple array
///
/// See [dc_array_t Class Reference](https://c.delta.chat/classdc__array__t.html
public class DcArray {
    private var dcArrayPointer: OpaquePointer?

    public init(arrayPointer: OpaquePointer) {
        dcArrayPointer = arrayPointer
    }

    deinit {
        dc_array_unref(dcArrayPointer)
    }

    public var count: Int {
       return Int(dc_array_get_cnt(dcArrayPointer))
    }
}
