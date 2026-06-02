import SwiftUI

/// Celebration overlay for badge unlocks
struct BadgeUnlockCelebrationView: View {
    let badge: BadgeInstance
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotate: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Badge display
                VStack(spacing: 20) {
                    // Badge icon with glow
                    ZStack {
                        // Glow background
                        Circle()
                            .fill(badge.rarity.glowColor)
                            .frame(width: 200, height: 200)
                            .blur(radius: 20)

                        // Badge container
                        ZStack {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(badge.rarity.backgroundColor)

                            Image(systemName: badge.badgeID.icon)
                                .font(.system(size: 80, weight: .semibold))
                                .foregroundColor(badge.rarity.foregroundColor)
                        }
                        .frame(width: 160, height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(badge.rarity.borderColor, lineWidth: 3)
                        )
                    }
                    .scaleEffect(scale)
                    .rotationEffect(.degrees(rotate))

                    // Badge info
                    VStack(spacing: 12) {
                        Text("Badge Unlocked!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.accentGold)

                        Text(LocalizedStringKey(badge.badgeID.rawValue))
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(badge.rarity.foregroundColor)
                            Text(badge.rarity.label)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(badge.rarity.foregroundColor)
                        }

                        Text(badge.badgeID.description)
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .fill(AppTheme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .stroke(badge.rarity.borderColor, lineWidth: 2)
                )
                .opacity(opacity)

                Spacer()

                VStack(spacing: 10) {
                    // Share the badge at the moment of unlock.
                    AchievementShareButton(
                        message: "I just unlocked the \"\(badge.badgeID.rawValue)\" badge on SpendZero! 🏆 Crushing my no-spend challenge.",
                        tint: badge.rarity.foregroundColor
                    )

                    // Dismiss button
                    Button(action: onDismiss) {
                        Text("View Badges")
                            .font(AppTheme.headlineFont)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(AppTheme.paddingMedium)
                            .background(badge.rarity.foregroundColor)
                            .cornerRadius(AppTheme.cornerRadiusMedium)
                    }
                }
                .padding(.horizontal, AppTheme.paddingLarge)
                .padding(.bottom, AppTheme.paddingLarge)
            }
        }
        .onAppear {
            HapticManager.shared.trigger(.badgeEarned)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(
                Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
            ) {
                rotate = 5
            }
        }
    }
}

#Preview {
    BadgeUnlockCelebrationView(
        badge: BadgeInstance(badgeID: .sevenDayStreak, rarity: .rare),
        onDismiss: {}
    )
}
