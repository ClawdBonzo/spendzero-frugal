import SwiftUI

/// Animated flame indicator showing streak intensity (3-7 flames based on streak length)
struct StreakFlamesView: View {
    let currentStreak: Int

    var flameCount: Int {
        switch currentStreak {
        case 1...6:
            return 1
        case 7...13:
            return 3
        case 14...29:
            return 5
        default:
            return 7
        }
    }

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<flameCount, id: \.self) { index in
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(flameColor(for: index))
                    .scaleEffect(pulseScale)
                    .animation(
                        Animation.easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: pulseScale
                    )
            }
        }
        .onAppear {
            pulseScale = 1.1
        }
    }

    private func flameColor(for index: Int) -> Color {
        // Gradient from gold to orange based on flame position
        let hue = Double(1 - Double(index) / Double(flameCount - max(1, flameCount - 1))) * 0.05  // Yellow to orange
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
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
