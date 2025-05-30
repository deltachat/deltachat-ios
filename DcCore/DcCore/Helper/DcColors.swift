import UIKit

public struct DcColors {
    private static let white                                  = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    private static let actionCellBackgroundDark               = #colorLiteral(red: 0.1031623408, green: 0.1083367988, blue: 0.1185036376, alpha: 1)

    public static let primary = UIColor.systemBlue
    public static let highlight = UIColor.themeColor(light: UIColor.yellow, dark: UIColor.systemBlue)
    public static let colorDisabled = UIColor.themeColor(light: UIColor(white: 0.9, alpha: 1), dark: UIColor(white: 0.2, alpha: 1))
    public static let messagePrimaryColor = UIColor.themeColor(light: UIColor.rgb(red: 220, green: 248, blue: 198),
                                                        dark: UIColor.init(hexString: "224508"))
    public static let messageSecondaryColor = UIColor.themeColor(light: .white,
                                                                 dark: .black)
    public static let contactCellBackgroundColor = UIColor.themeColor(light: .white, dark: .black)
    public static let defaultBackgroundColor = UIColor.themeColor(light: .white, dark: .black)
    public static let defaultTransparentBackgroundColor = DcColors.defaultBackgroundColor.withAlphaComponent(0.5)
    public static let defaultInverseColor = UIColor.themeColor(light: .black, dark: .white)
    public static let profileCellBackgroundColor = UIColor.themeColor(light: white, dark: actionCellBackgroundDark)
    public static let chatBackgroundColor = UIColor.themeColor(light: .white, dark: .black)
    public static let checkmarkGreen = UIColor.themeColor(light: UIColor.rgb(red: 112, green: 177, blue: 92))
    public static let recentlySeenDot = UIColor(hexString: "34c759")
    public static let unreadBadge = UIColor(hexString: "3792fc")
    public static let unreadBadgeMuted = UIColor.themeColor(light: UIColor.init(hexString: "b6b6bb"), dark: UIColor.init(hexString: "3b3b3b"))
    public static let defaultTextColor = UIColor.themeColor(light: .darkText, dark: .white)
    public static let grayTextColor = UIColor.themeColor(light: .darkGray, dark: coreDark05)
    public static let coreDark05 = UIColor.init(hexString: "EFEFEF")
    public static let grey50 = UIColor.init(hexString: "808080")
    public static let unknownSender = UIColor.init(hexString: "999999")
    public static let incomingMessageSecondaryTextColor = UIColor.themeColor(light: grey50, dark: coreDark05)
    public static let middleGray = UIColor(hexString: "848ba7")
    public static let secondaryTextColor = UIColor.themeColor(lightHex: "848ba7", darkHex: "a5abc0")
    public static let inputFieldColor =  UIColor.themeColor(
        light: UIColor(red: 200 / 255, green: 200 / 255, blue: 200 / 255, alpha: 0.25),
        dark: UIColor(red: 30 / 255, green: 30 / 255, blue: 30 / 255, alpha: 0.25))
    public static let placeholderColor = UIColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1)
    public static let providerPreparationBackground = UIColor.init(hexString: "fdf7b2")
    public static let providerBrokenBackground = UIColor.systemRed
    public static let systemMessageBackgroundColor = UIColor.init(hexString: "65444444")
    public static let systemMessageFontColor = UIColor.white
    public static let gotoButtonBackgroundColor = UIColor.init(hexString: "65666666")
    public static let gotoButtonFontColor = UIColor.init(hexString: "eeeeee")
    public static let deaddropBackground = UIColor.themeColor(light: UIColor.init(hexString: "f2f2f6"), dark: UIColor.init(hexString: "1a1a1c"))
    public static let selectBackground = UIColor.themeColor(light: UIColor.init(hexString: "d2d2d6"), dark: UIColor.init(hexString: "3a3a3c"))
    public static let accountSwitchBackgroundColor = UIColor.themeColor(light: UIColor.init(hexString: "65CCCCCC"), dark: UIColor.init(hexString: "65444444"))

    public static let myReactionLabel = UIColor.themeColor(light: UIColor(named: "Colors/MyReactionLabel")!)
    public static let reactionBackground = UIColor.themeColor(light: UIColor(named: "Colors/ReactionBackground")!)
    public static let reactionLabel = UIColor.themeColor(light: UIColor(named: "Colors/ReactionLabel")!)
    public static let reactionBorder = UIColor(named: "Colors/ReactionBorder")!
}
