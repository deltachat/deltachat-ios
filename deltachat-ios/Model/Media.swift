import CoreLocation
import Foundation
import UIKit

struct Media: MediaItem {
    var url: URL?

    var image: UIImage?

    var placeholderImage: UIImage = UIImage(color: .gray, size: CGSize(width: 250, height: 100))!
    var text: NSAttributedString?

    var size: CGSize {
        if let image = image {
            return image.size
        } else {
            return placeholderImage.size
        }
    }

    init(url: URL? = nil, image: UIImage? = nil, text: NSAttributedString? = nil) {
        self.url = url
        self.image = image
        self.text = text
    }
}
