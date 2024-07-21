import Foundation

extension UserDefaults {
    func populateDefaultEmojis() {
        let keys = DefaultReactions.allCases
            .reversed()
            .map { return "\($0.emoji)-usage-timestamps" }

        for key in keys {
            if array(forKey: key) == nil {
                setValue([Date().timeIntervalSince1970], forKey: key)
            } else if let timestamps = array(forKey: key), timestamps.isEmpty {
                setValue([Date().timeIntervalSince1970], forKey: key)
            }
        }
    }
}
