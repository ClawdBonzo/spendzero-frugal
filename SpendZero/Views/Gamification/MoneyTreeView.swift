import SwiftUI

/// Visual money tree that grows through level progression.
/// Uses Canvas with GeometryReader for adaptive sizing, particle overlay,
/// and accessibilityReduceMotion support.
struct MoneyTreeView: View {
    let gameProfile: GameProfile
    var streak: Int = 0
    var totalSaved: Double = 0
    /// True once the user has had a streak and let it lapse — the tree wilts until they return.
    var thirsty: Bool = false

    /// 0…1, continuous across all 25 levels so the tree grows a little with every level.
    private var growth: Double {
        let lvl = Double(gameProfile.currentLevel - 1) + gameProfile.progressToNextLevel
        return min(1, max(0.1, lvl / 24))
    }
    private var vitality: Double { thirsty ? 0.3 : min(1, 0.62 + Double(streak) / 25) }
    private var coins: Int { min(18, Int(totalSaved / 50)) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var treeStage: Int {
        switch gameProfile.currentLevel {
        case ...5:  return 1   // Seedling
        case ...10: return 2   // Sprout
        case ...15: return 3   // Young Tree
        case ...20: return 4   // Tall Tree
        default:    return 5   // Full Palm
        }
    }

    var stageIcon: String {
        switch treeStage {
        case 1: return "leaf.fill"
        case 2: return "leaf.circle.fill"
        case 3: return "tree.fill"
        case 4: return "tree.fill"
        default: return "crown.fill"
        }
    }

    var stageTitle: String {
        switch treeStage {
        case 1: return String(localized: "Seedling")
        case 2: return String(localized: "Sprout")
        case 3: return String(localized: "Young Tree")
        case 4: return String(localized: "Tall Tree")
        default: return String(localized: "Full Palm")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("Your Wealth Tree")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Growing with your financial wisdom")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            WealthTreeCanvas(seed: gameProfile.id.seed64, growth: growth, vitality: vitality, coins: coins)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel("Wealth tree at stage \(treeStage): \(stageTitle)")

            // Vitality: the tree reflects the streak, so a lapse is visible (and fixable).
            HStack(spacing: 8) {
                Image(systemName: thirsty ? "drop.triangle.fill" : (streak > 0 ? "flame.fill" : "leaf.fill"))
                Text(thirsty ? String(localized: "Your tree is thirsty — log a no-spend day to revive it")
                     : streak > 0 ? String(localized: "Thriving · \(streak)-day streak")
                     : String(localized: "Freshly planted — every no-spend day helps it grow"))
                    .lineLimit(2)
                Spacer(minLength: 0)
                if coins > 0 {
                    Label("\(coins)", systemImage: "circle.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundColor(AppTheme.accentGold)
                        .accessibilityLabel(String(localized: "\(coins) gold coins"))
                }
            }
            .font(.app(size: 13, weight: .semibold))
            .foregroundColor(thirsty ? AppTheme.warning : AppTheme.primaryGreen)
            .accessibilityValue("Level \(gameProfile.currentLevel)")

            // Stage info
            VStack(spacing: 8) {
                HStack {
                    Text("Current Stage")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: stageIcon)
                            .font(.app(size: 16, weight: .semibold))
                        Text(stageTitle)
                            .font(AppTheme.headlineFont)
                    }
                    .foregroundColor(AppTheme.accentGold)
                }

                if treeStage < 5 {
                    let nextStageLevel = treeStage * 5 + 1
                    VStack(spacing: 6) {
                        HStack {
                            Text("Level \(nextStageLevel) for next stage")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                            Spacer()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.cardBackgroundLight)
                                    .frame(height: 8)
                                let progress = min(1.0, Double(gameProfile.currentLevel) / Double(nextStageLevel))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [AppTheme.primaryGreen, AppTheme.accentGold],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * progress, height: 8)
                                    .animation(reduceMotion ? nil : .spring(response: 0.6), value: gameProfile.currentLevel)
                            }
                        }
                        .frame(height: 8)
                    }
                } else {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(AppTheme.accentGold)
                        Text("Wealth King — Ultimate status achieved!")
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.accentGold)
                    }
                }
            }
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
        .padding(AppTheme.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.background)
        )

    }

}

#Preview {
    let profile = GameProfile()
    profile.currentLevel = 15
    return MoneyTreeView(gameProfile: profile)
        .background(AppTheme.background)
}
