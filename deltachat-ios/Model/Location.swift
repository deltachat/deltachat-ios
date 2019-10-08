import CoreLocation
import Foundation
import UIKit

struct Location: LocationItem {
    var location: CLLocation

    var size: CGSize

    init(location: CLLocation, size: CGSize) {
        self.location = location
        self.size = size
    }
}
