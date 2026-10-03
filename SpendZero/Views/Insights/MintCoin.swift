import SwiftUI

/// Palette for minted gold, shared by the year grid, chart coin markers and callouts.
enum MintPalette {
    /// Brightness levels by amount kept: dull bronze-gold, coin gold, bright pale gold.
    static let levels: [[Color]] = [
        [Color(hex: "D9A23A"), Color(hex: "A8740A"), Color(hex: "6E4A05")],
        [Color(hex: "FFF1A8"), Color(hex: "FFC83D"), Color(hex: "B77A04")],
        [Color(hex: "FFFBE0"), Color(hex: "FFE27A"), Color(hex: "E0A21A")]
    ]
    static let glow = Color(hex: "FFE27A")
    static let missed = Color(hex: "1E2632")
    static let future = Color(hex: "111720")
    static let rim = Color(hex: "7A4E00")
}

/// A small minted coin: radial gold body lit from the top-left, a darker rim and a glint.
/// Cheap enough to use as a chart symbol or list glyph.
struct MintCoin: View {
    var size: CGFloat = 14
    var level: Int = 1
    var glow: Bool = false

    var body: some View {
        let colors = MintPalette.levels[max(0, min(2, level))]
        ZStack {
            if glow {
                Circle()
                    .fill(RadialGradient(colors: [MintPalette.glow.opacity(0.7), MintPalette.glow.opacity(0)],
                                         center: .center, startRadius: size * 0.3, endRadius: size * 1.05))
                    .frame(width: size * 2.1, height: size * 2.1)
            }
            Circle()
                .fill(RadialGradient(colors: colors, center: UnitPoint(x: 0.32, y: 0.28),
                                     startRadius: 0, endRadius: size * 0.75))
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(MintPalette.rim.opacity(0.45), lineWidth: max(0.5, size * 0.08)))
                .overlay(
                    Circle()
                        .trim(from: 0.55, to: 0.8)
                        .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: max(0.5, size * 0.07), lineCap: .round))
                        .padding(size * 0.2)
                )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
