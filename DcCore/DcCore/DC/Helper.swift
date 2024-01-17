import Foundation
import UIKit
import AVFoundation

public func mayBeValidAddr(email: String) -> Bool {
    return dc_may_be_valid_addr(email) != 0
}
