import SwiftUI

// Felt-table inspired palette (port of ui/Theme.kt)
enum Theme {
    static let tableGreen = Color(red: 0x1B / 255.0, green: 0x5E / 255.0, blue: 0x20 / 255.0)
    static let tableGreenDark = Color(red: 0x0D / 255.0, green: 0x33 / 255.0, blue: 0x11 / 255.0)
    static let accentGold = Color(red: 0xD4 / 255.0, green: 0xAF / 255.0, blue: 0x37 / 255.0)
    static let cardRed = Color(red: 0xC6 / 255.0, green: 0x28 / 255.0, blue: 0x28 / 255.0)
    static let accentYellow = Color(red: 1.0, green: 0xB1 / 255.0, blue: 0.0)
    static let background = Color(red: 0x10 / 255.0, green: 0x10 / 255.0, blue: 0x10 / 255.0)
}

/// Shorthand for catalog strings.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func LF(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, arguments: args)
}
