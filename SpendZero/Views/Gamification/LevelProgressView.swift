import SwiftUI

/// Full 25-level progression page with unlock features and cumulative XP requirements
struct LevelProgressView: View {
    let gameProfile: GameProfile

    @State private var selectedLevel: Int?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                Text("Level Progression")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Reach Level 25 to become the Wealth King")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.paddingLarge)

            // Current Progress Summary
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Level")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textTertiary)
                    Text("\(gameProfile.currentLevel)")
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.accentGold)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total XP")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textTertiary)
                    Text(String(gameProfile.totalXPEarned))
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textPrimary)
                }

                Spacer()
            }
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .padding(.horizontal, AppTheme.paddingLarge)

            // Levels Grid
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(1...25, id: \.self) { level in
                        let rank = LevelRank(rawValue: level)
                        let isUnlocked = gameProfile.currentLevel >= level
                        let isCurrent = gameProfile.currentLevel == level

                        LevelRowView(
                            level: level,
                            rank: rank,
                            isUnlocked: isUnlocked,
                            isCurrent: isCurrent,
                            isSelected: selectedLevel == level,
                            onTap: { selectedLevel = selectedLevel == level ? nil : level }
                        )
                        .padding(.horizontal, AppTheme.paddingLarge)

                        // Expanded Details
                        if selectedLevel == level, let rank = rank {
                            VStack(alignment: .leading, spacing: 12) {
                                Divider()
                                    .overlay(AppTheme.cardBackgroundLight)
                                    .padding(.horizontal, AppTheme.paddingMedium)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Unlocks")
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textSecondary)

                                    ForEach(rank.unlockedFeatures, id: \.self) { feature in
                                        HStack(spacing: 8) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(AppTheme.accentGold)
                                            Text(feature)
                                                .font(AppTheme.smallFont)
                                                .foregroundColor(AppTheme.textPrimary)
                                        }
                                    }
                                }
                                .padding(AppTheme.paddingMedium)
                                .background(AppTheme.cardBackgroundLight)
                                .cornerRadius(AppTheme.cornerRadiusMedium)
                                .padding(.horizontal, AppTheme.paddingMedium)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, AppTheme.paddingLarge)
                        }
                    }
                }
            }

            Spacer(minLength: 20)
        }
        .padding(.vertical, AppTheme.paddingLarge)
        .background(AppTheme.background)
    }
}

// MARK: - Level Row Component

struct LevelRowView: View {
    let level: Int
    let rank: LevelRank?
    let isUnlocked: Bool
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Level Badge
                    ZStack {
                        Circle()
                            .fill(
                                isCurrent
                                    ? LinearGradient(
                                        gradient: Gradient(colors: [
                                            AppTheme.primaryGreen,
                                            AppTheme.accentGold,
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        gradient: Gradient(colors: [
                                            isUnlocked ? AppTheme.primaryGreen : AppTheme.cardBackgroundLight,
                                            isUnlocked ? AppTheme.accentGold : AppTheme.textTertiary,
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )

                        Text(String(level))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isCurrent || isUnlocked ? .white : AppTheme.textSecondary)
                    }
                    .frame(width: 40, height: 40)

                    // Level Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rank?.title ?? "Unknown")
                                .font(AppTheme.bodyFont)
                                .foregroundColor(isUnlocked ? AppTheme.textPrimary : AppTheme.textTertiary)
                                .strikethrough(false)

                            if isCurrent {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.primaryGreen)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }

                        HStack(spacing: 4) {
                            Text(cumulativeXPForLevel(level))
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.accentGold)

                            if !isUnlocked {
                                Text("Total XP")
                                    .font(AppTheme.smallFont)
                                    .foregroundColor(AppTheme.textTertiary)
                            } else {
                                Text("Total XP")
                                    .font(AppTheme.smallFont)
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(AppTheme.paddingMedium)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadiusMedium)

                if isSelected {
                    Color.clear.frame(height: 0)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func cumulativeXPForLevel(_ level: Int) -> String {
        let totalXP = calculateCumulativeXP(for: level)
        return String(format: "%,d", totalXP)
    }

    private func calculateCumulativeXP(for level: Int) -> Int {
        var total = 0
        var xp = 300  // Base XP for level 1
        for _ in 1..<level {
            total += xp
            xp = Int(Double(xp) * 1.2)  // 20% growth per level
        }
        return total
    }
}

// MARK: - Preview

#Preview {
    let profile = GameProfile()
    profile.currentLevel = 12
    profile.totalXPEarned = 5000

    return LevelProgressView(gameProfile: profile)
        .background(AppTheme.background)
}
