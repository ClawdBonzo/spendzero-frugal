import SwiftUI

/// Full-screen celebration overlay for level-up events
struct LevelUpCelebrationView: View {
    let newLevel: Int
    let rank: LevelRank
    let previousLevel: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var starPulse = false
    @State private var confetti = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            GlowBackdrop(colors: [AppTheme.accentGold, AppTheme.primaryGreen, Color(hex: "FF8C00")], intensity: 0.16)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Level-up card
                VStack(spacing: 20) {
                    // Animated star / crown
                    ZStack {
                        Sunburst(color: AppTheme.accentGold, rays: 16)
                            .frame(width: 260, height: 260)
                            .opacity(cardOpacity)
                        Circle()
                            .fill(AppTheme.accentGold.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .scaleEffect(starPulse ? 1.15 : 0.9)

                        Image(systemName: "crown.fill")
                            .font(.app(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.accentGold, Color(hex: "FF8C00")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: starPulse
                    )

                    // LEVEL UP text
                    Text("LEVEL UP!")
                        .font(.app(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accentGold, AppTheme.primaryGreen],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )

                    // Before → After
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text("Level \(previousLevel)")
                                .font(.app(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Before")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.app(size: 28))
                            .foregroundColor(AppTheme.primaryGreen)

                        VStack(spacing: 4) {
                            Text("Level \(newLevel)")
                                .font(.app(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.accentGold)
                            Text("Now")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Rank title
                    Text(rank.title)
                        .font(.app(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen)

                    // Unlocked features
                    if !rank.unlockedFeatures.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("New Unlocks")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textTertiary)

                            ForEach(rank.unlockedFeatures.prefix(3), id: \.self) { feature in
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.app(size: 12))
                                        .foregroundColor(AppTheme.primaryGreen)
                                    Text(LocalizedStringKey(feature))
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppTheme.primaryGreen.opacity(0.5), AppTheme.accentGold.opacity(0.5)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                )
                .shadow(color: AppTheme.primaryGreen.opacity(0.2), radius: 20, y: 8)
                .padding(.horizontal, 24)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                Spacer()

                VStack(spacing: 10) {
                    // Share at the peak emotional moment.
                    AchievementShareButton(
                        message: String(localized: "I just hit Level \(newLevel) — \(rank.title) — on my no-spend journey with SpendZero! 💪 Building real savings one day at a time."),
                        tint: AppTheme.accentGold
                    )

                    // Dismiss button
                    Button(action: onDismiss) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("Awesome!")
                        }
                        .font(.app(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .overlay { CashConfettiBurst(trigger: confetti, origin: UnitPoint(x: 0.5, y: 0.3)).ignoresSafeArea() }
        .onAppear {
            HapticManager.shared.trigger(.levelUp)
            withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    starPulse = true
                }
                // Card lands first, then the burst on the beat.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    confetti += 1
                    CoinHaptics.levelUp()
                    SoundEffects.play(.levelUp)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Level up! You reached Level \(newLevel): \(rank.title)")
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    LevelUpCelebrationView(
        newLevel: 12,
        rank: .fortuneWeaver,
        previousLevel: 11,
        onDismiss: {}
    )
}
