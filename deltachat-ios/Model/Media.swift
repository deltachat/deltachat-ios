import CoreLocation
import Foundation
import MessageKit

struct Media: MediaItem {
  var url: URL?

  var image: UIImage?

  var placeholderImage: UIImage = UIImage(named: "ic_attach_file_36pt")!

  var size: CGSize {
    if let image = image {
      return image.size
    } else {
      return placeholderImage.size
    }
  }

  init(url: URL? = nil, image: UIImage? = nil) {
    self.url = url
    self.image = image
  }
}
