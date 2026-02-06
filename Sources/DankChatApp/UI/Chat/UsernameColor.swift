import SwiftUI
import UIKit

enum UsernameColor {
    static func color(from hex: String?) -> Color? {
        guard let hex else { return nil }
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard normalized.count == 6, let value = UInt32(normalized, radix: 16) else { return nil }

        let red = CGFloat((value & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((value & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(value & 0x0000FF) / 255.0
        return Color(uiColor: UIColor(red: red, green: green, blue: blue, alpha: 1))
    }
}
