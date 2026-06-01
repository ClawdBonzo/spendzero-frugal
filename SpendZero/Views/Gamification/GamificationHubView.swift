import SwiftUI
import SwiftData

/// Unified gamification hub displaying all progression, quests, badges, and visual elements
struct GamificationHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var gameProfile: GameProfile? { profile?.gameProfile }
    @State private var showHero = false
    @State private var showQuests = false
    @State private var showBadges = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if let gameProfile = gameProfile {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 4) {
                            Text("Your Gamification Hub")
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Track progress, complete quests, unlock badges")
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.paddingLarge)
                        .offset(x: showHero ? 0 : -30)
                        .opacity(showHero ? 1 : 0)

                        // Level Card Hero — scale in
                        LevelCard(gameProfile: gameProfile, currentStreak: profile?.currentStreak ?? 0)
                            .padding(.horizontal, AppTheme.paddingLarge)
                            .scaleEffect(showHero ? 1 : 0.92)
                            .opacity(showHero ? 1 : 0)

                        // Money Tree
                        MoneyTreeView(gameProfile: gameProfile)
                            .padding(.horizontal, AppTheme.paddingLarge)
                            .offset(y: showQuests ? 0 : 25)
                            .opacity(showQuests ? 1 : 0)

                        // Quick Stats
                        HStack(spacing: 12) {
                            StatTile(
                                label: "Badges",
                                value: "\(gameProfile.badges.count)",
                                icon: "medal.fill",
                                color: AppTheme.accentGold
                            )

                            StatTile(
                                label: "Next Level",
                                value: "\(gameProfile.xpThresholdForNextLevel - gameProfile.currentXP) XP",
                                icon: "star.fill",
                                color: AppTheme.primaryGreen
                            )

                            StatTile(
                                label: "Quests",
                                value: "\(gameProfile.quests.filter { !$0.isExpired }.count)",
                                icon: "checkmark.circle.fill",
                                color: AppTheme.info
                            )
                        }
                        .padding(.horizontal, AppTheme.paddingLarge)

                        // Quests Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Daily Quests")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                NavigationLink {
                                    QuestPanelView(gameProfile: gameProfile)
                                } label: {
                                    Text("See All")
                                        .font(AppTheme.smallFont)
                                        .foregroundColor(AppTheme.accentGold)
                                }
                            }
                            .padding(.horizontal, AppTheme.paddingLarge)

                            let dailyQuests = gameProfile.quests.filter { $0.isDaily && !$0.isExpired }
                            if dailyQuests.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.primaryGreen)
                                    Text("All daily quests complete!")
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                }
                                .padding(AppTheme.paddingMedium)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(AppTheme.cornerRadiusMedium)
                                .padding(.horizontal, AppTheme.paddingLarge)
                            } else {
                                ForEach(dailyQuests.prefix(2), id: \.id) { quest in
                                    QuestQuickView(quest: quest)
                                        .padding(.horizontal, AppTheme.paddingLarge)
                                }
                            }
                        }

                        // Badges Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Badges")
                                    .font(AppTheme.headlineFont)
                                    .foregroundColor(AppTheme.textPrimary)

                                Spacer()

                                NavigationLink {
                                    BadgeShowcaseView(gameProfile: gameProfile)
                                } label: {
                                    Text("View All")
                                        .font(AppTheme.smallFont)
                                        .foregroundColor(AppTheme.accentGold)
                                }
                            }
                            .padding(.horizontal, AppTheme.paddingLarge)

                            if gameProfile.badges.isEmpty {
                                HStack {
                                    Image(systemName: "medal")
                                        .foregroundColor(AppTheme.textTertiary)
                                    Text("Complete milestones to earn badges")
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                }
                                .padding(AppTheme.paddingMedium)
                                .background(AppTheme.cardBackground)
                                .cornerRadius(AppTheme.cornerRadiusMedium)
                                .padding(.horizontal, AppTheme.paddingLarge)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(
                                        gameProfile.badges
                                            .sorted { $0.earnedDate > $1.earnedDate }
                                            .prefix(6),
                                        id: \.id
                                    ) { badge in
                                        BadgeMiniView(badge: badge)
                                    }
                                }
                                .padding(.horizontal, AppTheme.paddingLarge)
                            }
                        }

                        // Progression Link
                        NavigationLink {
                            LevelProgressView(gameProfile: gameProfile)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Full Progression")
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("View all 25 levels and unlock features")
                                        .font(AppTheme.smallFont)
                                        .foregroundColor(AppTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(AppTheme.paddingMedium)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(AppTheme.cornerRadiusMedium)
                        }
                        .padding(.horizontal, AppTheme.paddingLarge)

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, AppTheme.paddingLarge)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                            showHero = true
                        }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                            showQuests = true
                        }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35)) {
                            showBadges = true
                        }
                    }
                } else {
                    Text("Loading gamification profile...")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

// MARK: - Stat Tile Component

struct StatTile: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
    }
}

// MARK: - Quest Quick View

struct QuestQuickView: View {
    let quest: Quest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.title)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("\(quest.difficulty.baseXP) XP")
                            .font(AppTheme.smallFont)
                    }
                    .foregroundColor(AppTheme.accentGold)
                }

                Spacer()

                Image(systemName: quest.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(quest.isCompleted ? AppTheme.primaryGreen : AppTheme.textTertiary)
            }

            if quest.targetValue > 0 {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.cardBackgroundLight)
                        .frame(height: 4)

                    let progress = min(1.0, quest.currentProgress / quest.targetValue)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.primaryGreen)
                        .frame(width: 280 * progress, height: 4)
                }
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Badge Mini View

struct BadgeMiniView: View {
    let badge: BadgeInstance

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(badge.rarity.backgroundColor)

                Image(systemName: badge.badgeID.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(badge.rarity.foregroundColor)
            }
            .frame(height: 70)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(badge.rarity.borderColor, lineWidth: 1.5)
            )

            Text(LocalizedStringKey(badge.badgeID.rawValue))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
        }
    }
}

#Preview {
    let profile = GameProfile()
    profile.currentLevel = 12
    profile.totalXPEarned = 5000

    return GamificationHubView()
        .background(AppTheme.background)
}
