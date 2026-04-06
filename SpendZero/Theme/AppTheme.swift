import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let background = Color(hex: "0A0E14")
    static let cardBackground = Color(hex: "141A24")
    static let cardBackgroundLight = Color(hex: "1C2430")
    static let surfaceElevated = Color(hex: "1E2736")

    static let primaryGreen = Color(hex: "00E676")
    static let primaryGreenDark = Color(hex: "00C853")
    static let accentGold = Color(hex: "FFD740")
    static let accentGoldDark = Color(hex: "FFC400")

    static let destructive = Color(hex: "FF5252")
    static let warning = Color(hex: "FF9800")
    static let info = Color(hex: "448AFF")

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8899AA")
    static let textTertiary = Color(hex: "556677")

    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [primaryGreen, Color(hex: "00BFA5")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [accentGold, Color(hex: "FFB300")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [cardBackground, cardBackgroundLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradient = LinearGradient(
        colors: [
            primaryGreen.opacity(0.15),
            Color(hex: "00BFA5").opacity(0.05),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Typography
    static let displayFont = Font.system(size: 34, weight: .bold, design: .rounded)
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular)
    static let captionFont = Font.system(size: 13, weight: .medium)
    static let smallFont = Font.system(size: 11, weight: .medium)

    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let paddingXL: CGFloat = 32

    // MARK: - Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20
    static let cornerRadiusFull: CGFloat = 100
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
