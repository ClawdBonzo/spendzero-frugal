import SwiftUI

/// Animated flame indicator showing streak intensity (0-5 flames based on streak length).
/// Always renders 5 flame slots — earned ones glow orange, unearned are dim outlines.
struct StreakFlamesView: View {
    let currentStreak: Int

    /// How many of the 5 slots are "lit" based on streak length
    var earnedFlames: Int {
        switch currentStreak {
        case 0:        return 0
        case 1...6:    return 1   // first day → first flame
        case 7...13:   return 2   // 1-week milestone
        case 14...29:  return 3   // 2-week milestone
        case 30...99:  return 4   // 1-month milestone
        default:       return 5   // 100+ day legend
        }
    }

    private let totalSlots = 5

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<totalSlots, id: \.self) { index in
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(flameColor(for: index))
                    .scaleEffect(index < earnedFlames ? pulseScale : 1.0)
                    .animation(
                        index < earnedFlames
                            ? .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1)
                            : .default,
                        value: pulseScale
                    )
            }
        }
        .onAppear {
            pulseScale = 1.12
        }
        .accessibilityLabel("\(earnedFlames) of \(totalSlots) streak flames lit")
    }

    private func flameColor(for index: Int) -> Color {
        guard index < earnedFlames else {
            // Dim outline for unearned slots
            return AppTheme.textTertiary.opacity(0.25)
        }
        // Gradient from gold (first) → deep orange (last earned)
        let progress = earnedFlames <= 1 ? 0 : Double(index) / Double(earnedFlames - 1)
        let startHue = 0.13   // gold
        let endHue   = 0.04   // deep orange/red
        let hue = startHue + (endHue - startHue) * progress
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Day 5:")
            StreakFlamesView(currentStreak: 5)
        }
        HStack {
            Text("Day 10:")
            StreakFlamesView(currentStreak: 10)
        }
        HStack {
            Text("Day 25:")
            StreakFlamesView(currentStreak: 25)
        }
        HStack {
            Text("Day 100:")
            StreakFlamesView(currentStreak: 100)
        }
    }
    .padding()
}
