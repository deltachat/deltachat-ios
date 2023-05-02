import Foundation
import UIKit

extension String {

    func substring(_ from: Int, _ to: Int) -> String {
        let idx1 = index(startIndex, offsetBy: from)
        let idx2 = index(startIndex, offsetBy: to)
        return String(self[idx1..<idx2])
    }

    func substring(to: Index) -> String {
        return String(self[startIndex..<to])
    }

    func ranges(of string: String, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
            let range = self[startIndex...].range(of: string, options: options) {
                result.append(range)
                startIndex = range.lowerBound < range.upperBound ? range.upperBound :
                    index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }

    // O(n) - returns indexes of subsequences -> can be used to highlight subsequence within string
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

    func subScript(_ i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }

    func bold(fontSize: CGFloat) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: self)
        attributedText.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: fontSize), range: NSRange(location: 0, length: count - 1))
        return attributedText
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

    // required for jumbomoji logic
    // thanks to https://stackoverflow.com/a/39425959
    var containsOnlyEmoji: Bool {
        // Character.isEmoji is defined in deltachat-ios/Extensions/Character+Extension.swift
        return !isEmpty && !contains { !$0.isEmoji }
    }
}
