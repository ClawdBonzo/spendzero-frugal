import SwiftUI

/// Hero card displaying current level, XP progress, and next level preview
struct LevelCard: View {
    let gameProfile: GameProfile
    let currentStreak: Int

    var nextLevelXP: Int {
        gameProfile.xpThresholdForNextLevel
    }

    var xpProgress: Double {
        gameProfile.progressToNextLevel
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header: Level and Rank
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(gameProfile.currentLevel)")
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.textPrimary)
                    Text(gameProfile.currentRank.title)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                // XP Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text("XP")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textTertiary)
                    Text(String(gameProfile.totalXPEarned))
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.accentGold)
                }
            }

            // XP Progress Bar
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    // Progress bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .fill(AppTheme.cardBackgroundLight)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppTheme.primaryGreen, AppTheme.accentGold]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 240 * xpProgress, height: 12)
                    }
                    .frame(maxWidth: 240)

                    // Percentage
                    Text(String(format: "%.0f%%", xpProgress * 100))
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 35)
                }

                // XP Text
                HStack {
                    Text(String(gameProfile.currentXP) + "/" + String(nextLevelXP) + " XP")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textSecondary)

                    Spacer()

                    if xpProgress >= 0.8 {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                            Text("Almost there!")
                                .font(AppTheme.smallFont)
                        }
                        .foregroundColor(AppTheme.accentGold)
                    }
                }
            }

            // Next Level Preview
            if gameProfile.currentLevel < 25 {
                VStack(spacing: 6) {
                    Divider()
                        .overlay(AppTheme.cardBackgroundLight)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Next Level")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                            Text("Level \(gameProfile.currentLevel + 1): " + (LevelRank(rawValue: gameProfile.currentLevel + 1)?.title ?? ""))
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Unlocks")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)

                            HStack(spacing: 4) {
                                ForEach(
                                    (LevelRank(rawValue: gameProfile.currentLevel + 1)?.unlockedFeatures ?? []).prefix(2),
                                    id: \.self
                                ) { feature in
                                    Text(feature)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(AppTheme.primaryGreen)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(AppTheme.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "1A2433"),
                        AppTheme.cardBackground
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            AppTheme.primaryGreen.opacity(0.3),
                            AppTheme.accentGold.opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    let profile = GameProfile()
    profile.currentLevel = 12
    profile.currentXP = 250
    profile.totalXPEarned = 5000

    return LevelCard(gameProfile: profile, currentStreak: 15)
        .padding()
        .background(AppTheme.background)
}
