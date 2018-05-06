//
//  Utils.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 08.11.17.
//  Copyright © 2017 Jonas Reinsch. All rights reserved.
//

import Foundation
import UIKit

struct Utils {
    static func colorIndex(row: Int, colors:[UIColor]) -> Int {
        return row % colors.count
    }
    
    static func color(row: Int, colors:[UIColor]) -> UIColor {
        let index = colorIndex(row: row, colors: colors)
        return colors[index]
    }
    
    static func getContactIds() -> [Int] {
        let c_contacts = mrmailbox_get_known_contacts(mailboxPointer, nil)
        return Utils.copyAndFreeArray(inputArray: c_contacts)
    }

    static func getInitials(inputName:String) -> String {
        let nameParts = inputName.split(separator: " ")
        let initials:[Character] = nameParts.compactMap {part in part.first}
        let initialsString:String = String(initials)
        return initialsString
    }

    static func copyAndFreeArray(inputArray:UnsafeMutablePointer<mrarray_t>?) -> [Int] {
        var acc:[Int] = []
        let len = mrarray_get_cnt(inputArray)
        for i in 0 ..< len {
            let e = mrarray_get_id(inputArray, i)
            acc.append(Int(e))
        }
        mrarray_unref(inputArray)
        return acc
    }
    
    
    static func isValid(_ email: String) -> Bool {
        let emailRegEx = "(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"+"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"+"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"+"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"+"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"+"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"+"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"
        
        let emailTest = NSPredicate(format:"SELF MATCHES[c] %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
}


extension UIColor {
    convenience init(alpha: Int, red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: CGFloat(alpha) / 255)
    }
    
    convenience init(netHex: Int) {
        var alpha = (netHex >> 24) & 0xff
        if alpha == 0 {
            alpha = 255
        }
        
        self.init(alpha: alpha, red:(netHex >> 16) & 0xff, green:(netHex >> 8) & 0xff, blue:netHex & 0xff)
    }

    // see: https://stackoverflow.com/a/33397427
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt32()
        Scanner(string: hex).scanHexInt32(&int)
        let a, r, g, b: UInt32
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
