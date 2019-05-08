//
//  Colors.swift
//  deltachat-ios
//
//  Created by Bastian van de Wetering on 17.04.19.
//  Copyright © 2019 Jonas Reinsch. All rights reserved.
//

import UIKit

struct DCColors {
  static let primary = UIColor.systemBlue
  // static let accent =

  static let messagePrimaryColor = UIColor.rgb(red: 220, green: 248, blue: 198)
  static let messageSecondaryColor = UIColor.rgb(red: 245, green: 245, blue: 245)
  static let chatBackgroundColor = UIColor.rgb(red: 236, green: 229, blue: 221)
}

enum SystemColor {
  case red
  case orange
  case yellow
  case green
  case tealBlue
  case blue
  case purple
  case pink

  var uiColor: UIColor {
    switch self {
    case .red:
      return UIColor(red: 255 / 255, green: 59 / 255, blue: 48 / 255, alpha: 1)
    case .orange:
      return UIColor(red: 255 / 255, green: 149 / 255, blue: 0 / 255, alpha: 1)
    case .yellow:
      return UIColor(red: 255 / 255, green: 204 / 255, blue: 0 / 255, alpha: 1)
    case .green:
      return UIColor(red: 76 / 255, green: 217 / 255, blue: 100 / 255, alpha: 1)
    case .tealBlue:
      return UIColor(red: 90 / 255, green: 200 / 255, blue: 250 / 255, alpha: 1)
    case .blue:
      return UIColor(red: 0 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
    case .purple:
      return UIColor(red: 88 / 255, green: 86 / 255, blue: 214 / 255, alpha: 1)
    case .pink:
      return UIColor(red: 255 / 255, green: 45 / 255, blue: 85 / 255, alpha: 1)
    }
  }
}

extension UIColor {
  static func rgb(red: CGFloat, green: CGFloat, blue: CGFloat) -> UIColor {
    return UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
  }

  static var systemBlue: UIColor {
    return UIButton(type: .system).tintColor
  }
}
