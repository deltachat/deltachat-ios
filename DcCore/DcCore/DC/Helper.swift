import Foundation
import UIKit
import AVFoundation

func strToBool(_ value: String?) -> Bool {
    if let vStr = value {
        if let vInt = Int(vStr) {
            return vInt == 1
        }
        return false
    }

    return false
}

public func mayBeValidAddr(email: String) -> Bool {
    return dc_may_be_valid_addr(email) != 0
}
