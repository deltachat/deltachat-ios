import UIKit

public extension UIColor {

    convenience init(alpha: Int, red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: CGFloat(alpha) / 255)
    }

    convenience init(netHex: Int) {
        var alpha = (netHex >> 24) & 0xFF
        if alpha == 0 {
            alpha = 255
        }

        self.init(alpha: alpha, red: (netHex >> 16) & 0xFF, green: (netHex >> 8) & 0xFF, blue: netHex & 0xFF)
    }

    // see: https://stackoverflow.com/a/33397427
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
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

    static func themeColor(light: UIColor, dark: UIColor? = nil) -> UIColor {
        if let dark {
            return UIColor.init { (trait) -> UIColor in
                return trait.userInterfaceStyle == .dark ? dark : light
            }
        } else {
            return light
        }
    }

    static func themeColor(lightHex: String, darkHex: String? = nil) -> UIColor {
        if let darkHex {
                return UIColor.init { (trait) -> UIColor in
                    return trait.userInterfaceStyle == .dark ? UIColor(hexString: darkHex) :  UIColor(hexString: lightHex)
                }
        } else {
            return UIColor(hexString: lightHex)
        }
    }

    static func rgb(red: CGFloat, green: CGFloat, blue: CGFloat) -> UIColor {
        return UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
    
    /// Returns a lighter version of the color
    /// - Parameter percentage: Percentage to lighten (0.0 - 1.0)
    /// - Returns: A lighter UIColor or nil if the operation fails
    func lighter(by percentage: CGFloat = 0.3) -> UIColor? {
        return adjust(by: abs(percentage))
    }
    
    /// Returns a darker version of the color
    /// - Parameter percentage: Percentage to darken (0.0 - 1.0)
    /// - Returns: A darker UIColor or nil if the operation fails
    func darker(by percentage: CGFloat = 0.3) -> UIColor? {
        return adjust(by: -abs(percentage))
    }
    
    /// Adjusts the brightness of the color
    /// - Parameter percentage: Positive value lightens, negative value darkens
    /// - Returns: An adjusted UIColor or nil if the operation fails
    private func adjust(by percentage: CGFloat) -> UIColor? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        return UIColor(
            red: min(max(red + percentage, 0.0), 1.0),
            green: min(max(green + percentage, 0.0), 1.0),
            blue: min(max(blue + percentage, 0.0), 1.0),
            alpha: alpha
        )
    }
    
    /// Determines if the color is light or dark based on perceived brightness
    /// - Returns: true if the color is light (perceived brightness > 0.5), false if dark
    func isLight() -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return true // Default to light if we can't determine
        }
        
        // Calculate perceived brightness using the relative luminance formula
        // https://www.w3.org/TR/WCAG20/#relativeluminancedef
        let brightness = (red * 0.299) + (green * 0.587) + (blue * 0.114)
        return brightness > 0.5
    }
}
