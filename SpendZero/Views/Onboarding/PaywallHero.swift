import SwiftUI

/// The paywall's living header: a minted coin that flips to reveal PRO each time the user picks
/// a plan, beside their 12-month forecast (when we have their answers) rolling up in gold.
struct PaywallHero: View {
    let forecast: SavingsForecast?
    let plan: SubscriptionOption?
    /// Incremented by the paywall only when the user taps a different plan.
    let flipTrigger: Int
    let subtitle: LocalizedStringKey

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0
    @State private var faces: [CoinFace] = [.pro(nil), .pro(nil)]
    @State private var minted = false
    @State private var shownTotal: Double = 0

    enum CoinFace: Equatable {
        case forecast(SavingsForecast)
        case pro(SubscriptionOption.ID?)
    }

    private let coinSize: CGFloat = 104

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            FlipCoin(angle: angle, front: face(faces[0]), back: face(faces[1]))
                .frame(width: coinSize, height: coinSize)
                .scaleEffect(minted ? 1 : 0.55)
                .opacity(minted ? 1 : 0)
                .rotationEffect(.degrees(minted ? 0 : -18))

            VStack(alignment: .leading, spacing: 3) {
                Text("SpendZero Pro")
                    .font(.app(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.app(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let forecast {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your 12-month forecast")
                            .textCase(.uppercase)
                            .font(.app(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(AppTheme.primaryGreen)
                        RollingMoney(value: shownTotal,
                                     font: .app(size: 30, weight: .black, design: .rounded),
                                     color: AppTheme.accentGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .goldSheen(0.8)
                            .shadow(color: AppTheme.accentGold.opacity(0.3), radius: 10, y: 2)
                    }
                    .padding(.top, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Your 12-month forecast"))
                    .accessibilityValue(Text(verbatim: forecast.total.currencyFormatted))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: mint)
        .onChange(of: flipTrigger) { _, _ in flip() }
        .onChange(of: plan?.id) { _, _ in
            // Prices arriving (or the plan list changing) refresh the PRO face without a flip.
            if case .pro = faces[visibleSlot] { faces[visibleSlot] = .pro(plan?.id) }
        }
    }

    // MARK: - Faces

    private var visibleSlot: Int {
        let a = angle.truncatingRemainder(dividingBy: 360)
        return (a < 90 || a >= 270) ? 0 : 1
    }

    @ViewBuilder
    private func face(_ face: CoinFace) -> some View {
        switch face {
        case .forecast(let f):
            SealMedallion(ringText: String(localized: "Your forecast"),
                          center: f.total.compactCurrency,
                          caption: f.endDate.formatted(.dateTime.month(.abbreviated).year()))
                .goldSheen()
        case .pro:
            SealMedallion(ringText: plan?.title ?? String(localized: "SpendZero Pro"),
                          center: String(localized: "PRO"),
                          caption: plan?.price ?? "")
                .goldSheen()
        }
    }

    // MARK: - Motion

    private func mint() {
        faces[0] = forecast.map(CoinFace.forecast) ?? .pro(plan?.id)
        guard !reduceMotion else {
            minted = true
            shownTotal = forecast?.total ?? 0
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62).delay(0.15)) { minted = true }
        if let total = forecast?.total {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shownTotal = total }
        }
    }

    private func flip() {
        let hidden = 1 - visibleSlot
        faces[hidden] = .pro(plan?.id)
        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.25)) { faces[visibleSlot] = .pro(plan?.id) }
            return
        }
        SoundEffects.play(.flip, volume: 0.35)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { angle += 180 }
    }
}

/// A two-sided coin turning about its vertical axis. The face swaps exactly at 90°, the coin lifts
/// toward the viewer mid-turn, and a sliver of reeded edge shows while it is side-on.
struct FlipCoin<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let a = ((angle.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let showFront = a < 90 || a >= 270
        let side = abs(sin(angle * .pi / 180))     // 0 face-on … 1 edge-on
        ZStack {
            // Edge thickness, visible only near side-on.
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: "8A5A00"), Color(hex: "FFC83D"), Color(hex: "8A5A00")],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 8)
                .opacity(side > 0.8 ? (side - 0.8) * 5 : 0)

            Group {
                if showFront {
                    front
                } else {
                    back.scaleEffect(x: -1, y: 1)   // un-mirror the far side
                }
            }
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        }
        .scaleEffect(1 + 0.1 * side)
        .shadow(color: .black.opacity(0.45), radius: 12 + 8 * side, y: 8 + 6 * side)
    }
}
