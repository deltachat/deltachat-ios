import Foundation
import UIKit

// required extentions to Character and String
// thanks to https://stackoverflow.com/a/39425959

extension Character {
    var isSimpleEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else {
            return false
        }
        return firstScalar.properties.isEmoji && firstScalar.value > 0x238C
    }
    var isCombinedIntoEmoji: Bool {
        unicodeScalars.count > 1 && unicodeScalars.first?.properties.isEmoji ?? false
    }
    var isEmoji: Bool { isSimpleEmoji || isCombinedIntoEmoji }
}

