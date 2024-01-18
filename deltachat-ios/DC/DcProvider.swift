import Foundation

/// Opaque object containing information about one single e-mail provider
///
/// See [dc_provider_t Class Reference](https://c.delta.chat/classdc__provider__t.html)
public class DcProvider {
    private var dcProviderPointer: OpaquePointer?

    // takes ownership of specified pointer
    public init(_ dcProviderPointer: OpaquePointer) {
        self.dcProviderPointer = dcProviderPointer
    }

    deinit {
        dc_provider_unref(dcProviderPointer)
    }

    public var status: Int {
        return Int(dc_provider_get_status(dcProviderPointer))
    }

    public var beforeLoginHint: String {
        guard let cString = dc_provider_get_before_login_hint(dcProviderPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }

    public var getOverviewPage: String {
        guard let cString = dc_provider_get_overview_page(dcProviderPointer) else { return "" }
        let swiftString = String(cString: cString)
        dc_str_unref(cString)
        return swiftString
    }
}
