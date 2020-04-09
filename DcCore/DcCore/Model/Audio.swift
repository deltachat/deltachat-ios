import CoreLocation
import Foundation
import UIKit

struct Audio: AudioItem {
    var size: CGSize = CGSize(width: 250, height: 50)

    var url: URL

    var duration: Float

    var text: NSAttributedString?

    init(url: URL, duration: Float, text: NSAttributedString? = nil) {
        self.url = url
        self.duration = duration
        self.text = text
    }
}
