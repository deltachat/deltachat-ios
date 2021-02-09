import Foundation
import DcCore

extension DcContact {
    func contains(searchText text: String) -> [ContactHighlights] {
        var nameIndexes = [Int]()
        var emailIndexes = [Int]()

        let contactString = displayName + email
        let subsequenceIndexes = contactString.contains(subSequence: text)

        if !subsequenceIndexes.isEmpty {
            for index in subsequenceIndexes {
                if index < displayName.count {
                    nameIndexes.append(index)
                } else {
                    let emailIndex = index - displayName.count
                    emailIndexes.append(emailIndex)
                }
            }
            return [ContactHighlights(contactDetail: .NAME, indexes: nameIndexes), ContactHighlights(contactDetail: .EMAIL, indexes: emailIndexes)]
        } else {
            return []
        }
    }

    func containsExact(searchText text: String) -> [ContactHighlights] {
        var contactHighlights = [ContactHighlights]()

        let nameString = displayName + ""
        let emailString = email + ""
        if let nameRange = nameString.range(of: text, options: .caseInsensitive) {
            let index: Int = nameString.distance(from: nameString.startIndex, to: nameRange.lowerBound)
            var nameIndexes = [Int]()
            for i in index..<(index + text.count) {
                nameIndexes.append(i)
            }
            contactHighlights.append(ContactHighlights(contactDetail: .NAME, indexes: nameIndexes))
        }

        if let emailRange = emailString.range(of: text, options: .caseInsensitive) {
            let index: Int = emailString.distance(from: emailString.startIndex, to: emailRange.lowerBound)
            var emailIndexes = [Int]()
            for i in index..<(index + text.count) {
                emailIndexes.append(i)
            }
            contactHighlights.append(ContactHighlights(contactDetail: .EMAIL, indexes: emailIndexes))
        }

        return contactHighlights
    }
}
