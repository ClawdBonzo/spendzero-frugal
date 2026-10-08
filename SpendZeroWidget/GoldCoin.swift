import SwiftUI
import WidgetKit

/// Brand palette for the extension (widgets can't run the app's Metal shaders, so gold is a gradient).
enum WidgetPalette {
    static let background = Color(hex: "0A0E14")
    static let card = Color(hex: "141A24")
    static let green = Color(hex: "00E676")
    static let gold = Color(hex: "FFD740")
    static let goldLight = Color(hex: "FFF3B0")
    static let goldDeep = Color(hex: "FFA000")
    static let goldInk = Color(hex: "4A3300")
    static let red = Color(hex: "FF5252")

    static var goldFace: LinearGradient {
        LinearGradient(colors: [goldLight, gold, goldDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var goldRim: AngularGradient {
        AngularGradient(colors: [goldDeep, goldLight, gold, goldDeep, goldLight, goldDeep], center: .center)
    }
    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [card, background], startPoint: .top, endPoint: .bottom)
    }
}

/// The streak coin. Its face flips (push transition + rolling number) when a new timeline entry
/// arrives after the user seals today.
struct GoldCoin: View {
    let streak: Int
    let sealed: Bool
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(WidgetPalette.goldRim)
            Circle()
                .fill(WidgetPalette.goldFace)
                .padding(size * 0.07)
            Circle()
                .strokeBorder(WidgetPalette.goldInk.opacity(0.25), lineWidth: max(1, size * 0.02))
                .padding(size * 0.13)
            // Specular highlight
            Ellipse()
                .fill(.white.opacity(0.35))
                .frame(width: size * 0.5, height: size * 0.22)
                .offset(x: -size * 0.1, y: -size * 0.24)
                .blur(radius: size * 0.04)

            face
                .id(sealed)
                .transition(.asymmetric(insertion: .push(from: .top), removal: .push(from: .bottom)))
        }
        .frame(width: size, height: size)
        .shadow(color: WidgetPalette.gold.opacity(0.45), radius: size * 0.12)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: sealed)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: streak)
    }

    private var face: some View {
        VStack(spacing: -size * 0.02) {
            Image(systemName: sealed ? "checkmark.seal.fill" : "flame.fill")
                .font(.system(size: size * 0.22, weight: .bold))
            Text("\(streak)")
                .font(.system(size: size * (streak >= 100 ? 0.27 : 0.34), weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(streak)))
        }
        .foregroundStyle(WidgetPalette.goldInk)
        .padding(.horizontal, size * 0.12)
    }
}

/// The coin as a one-tap "seal today" button. Disabled once today is sealed or has spending.
struct CoinSealButton: View {
    let entry: SavingsWidgetEntry
    var size: CGFloat = 56

    private var isEnabled: Bool { !entry.loggedToday && entry.isNoSpendDay }

    var body: some View {
        Button(intent: SealTodayIntent()) {
            GoldCoin(streak: entry.currentStreak, sealed: entry.loggedToday, size: size)
                .invalidatableContent()
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(entry.loggedToday
                            ? Text("Today is sealed. \(entry.currentStreak)-day streak")
                            : Text("Seal today. \(entry.currentStreak)-day streak"))
    }
}
