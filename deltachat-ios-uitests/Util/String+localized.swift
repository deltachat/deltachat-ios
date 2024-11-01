import Foundation

extension Bundle {
    static var uitest: Bundle {
        Bundle(for: ChatTests.self)
    }
}

public extension String {
    static func localized(_ stringID: String) -> String {
        return NSLocalizedString(stringID, bundle: .uitest, comment: "")
    }

    static func localized(stringID: String, parameter: CVarArg...) -> String {
        let formatString = localized(stringID)
        let resultString = String.localizedStringWithFormat(formatString, parameter)
        return resultString
    }
}
