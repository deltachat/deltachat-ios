import Foundation
import UIKit

public extension String {

    func markAsExternal() -> String {
        return self + " ↗"
    }

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

    static func localized(stringID: String, parameter: CVarArg...) -> String {
        let formatString = localized(stringID)
        let resultString = String.localizedStringWithFormat(formatString, parameter)
        return resultString
    }

    func containsExact(subSequence: String?) -> [Int] {
        guard let searchText = subSequence else {
            return []
        }
        if searchText.count > count {
            return []
        }

        if let range = range(of: searchText, options: .caseInsensitive) {
            let index: Int = distance(from: startIndex, to: range.lowerBound)
            var indexes: [Int] = []
            for i in index..<(index + searchText.count) {
                indexes.append(i)
            }
            return indexes
        }
        return []
    }

    func boldAt(indexes: [Int], fontSize: CGFloat) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: self)

        for index in indexes {
            if index < 0 || count <= index {
                break
            }
            attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: NSRange(location: index, length: 1))
        }
        return attributedText
    }
}

extension String? {
    /// returns `true` if `"1"`, returns `false` in case of `nil` or any other string
    var numericBoolValue: Bool {
        guard let self, let intValue = Int(self) else { return false }

        return intValue == 1
    }
}
