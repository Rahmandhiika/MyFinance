import SwiftUI

// NSCache is thread-safe and evicts automatically under memory pressure.
// Caching UIColor (not Color) because Color is a struct and can't be stored in NSCache directly.
private let hexColorCache = NSCache<NSString, UIColor>()

extension Color {
    init(hex: String) {
        let key = hex as NSString
        if let cached = hexColorCache.object(forKey: key) {
            self.init(uiColor: cached)
            return
        }

        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8 & 0xFF,int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16 & 0xFF,int>>8 & 0xFF,int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }

        let uiColor = UIColor(
            red:   CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue:  CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
        hexColorCache.setObject(uiColor, forKey: key)
        self.init(uiColor: uiColor)
    }
}
