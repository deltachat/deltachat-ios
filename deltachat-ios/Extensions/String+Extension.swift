import Foundation
import UIKit

extension String {

    func substring(_ from: Int, _ to: Int) -> String {
        let idx1 = index(startIndex, offsetBy: from)
        let idx2 = index(startIndex, offsetBy: to)
        return String(self[idx1..<idx2])
    }

    func containsCharacters() -> Bool {
        return !trimmingCharacters(in: [" "]).isEmpty
    }

    // O(n) - incremental search - returns indexes of subsequences -> can be used to highlight subsequence within string
    func contains(subSequence: String) -> [Int] {
        if subSequence.count > count {
            return []
        }

        let str = lowercased()
        let sub = subSequence.lowercased()

        var j = 0

        var foundIndexes: [Int] = []

        for (index, char) in str.enumerated() {
            if j == sub.count {
                break
            }

            if char == sub.subScript(j) {
                foundIndexes.append(index)
                j += 1
            }
        }
        return foundIndexes.count == sub.count ? foundIndexes : []
    }

    func containsExact(subSequence: String) -> [Int] {
        if subSequence.count > count {
            return []
        }

        if let range = range(of: subSequence, options: .caseInsensitive) {
            let index: Int = distance(from: startIndex, to: range.lowerBound)
            var indexes: [Int] = []
            for i in index..<(index + subSequence.count) {
                indexes.append(i)
            }
            return indexes
        }
        return []
    }

    func subScript(_ i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
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

    static func timeStringForInterval(_ interval: TimeInterval) -> String {
        let time = NSInteger(interval)
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = time / 3600

        if hours > 0 {
            return NSString.localizedStringWithFormat("%02li:%02li:%02li", hours, minutes, seconds) as String
        } else {
            return NSString.localizedStringWithFormat("%02li:%02li", minutes, seconds) as String
        }
    }
}
