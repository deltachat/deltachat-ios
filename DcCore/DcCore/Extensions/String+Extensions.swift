import Foundation
internal extension String {
    
    static func localized(_ stringID: String) -> String {
        let value = NSLocalizedString(stringID, comment: "")
        if value != stringID || NSLocale.preferredLanguages.first == "en" {
            return value
        }

        guard
            let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return value }
        return NSLocalizedString(stringID, bundle: bundle, comment: "")
    }

    static func localized(stringID: String, count: Int) -> String {
        let formatString: String = localized(stringID)
        let resultString: String = String.localizedStringWithFormat(formatString, count)
        return resultString
    }

}
