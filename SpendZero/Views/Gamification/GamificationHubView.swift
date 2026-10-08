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
            ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if let gameProfile = gameProfile {
                    VStack(spacing: 20) {
                        // Header — the tab is called "Quests", so quests come first.
                        VStack(spacing: 4) {
                            Text("Quests")
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.textPrimary)
                            Text("Earn XP through real no-spend wins")
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.paddingLarge)
                        .offset(x: showHero ? 0 : -30)
                        .opacity(showHero ? 1 : 0)

                        // Active quests — every daily quest and the weekly quest, with progress.
                        questsList(gameProfile: gameProfile)
                            .offset(y: showHero ? 0 : 20)
                            .opacity(showHero ? 1 : 0)

                        // Level Card
                        LevelCard(gameProfile: gameProfile, currentStreak: profile?.currentStreak ?? 0)
                            .padding(.horizontal, AppTheme.paddingLarge)
                            .scaleEffect(showQuests ? 1 : 0.92)
                            .opacity(showQuests ? 1 : 0)

                        // Money Tree
                        MoneyTreeView(gameProfile: gameProfile, streak: profile?.currentStreak ?? 0, totalSaved: profile?.totalSaved ?? 0,
                                      thirsty: (profile?.currentStreak ?? 0) == 0 && (profile?.longestStreak ?? 0) > 0)
                            .id("wealthTree")
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
                                value: String(localized: "\(gameProfile.xpThresholdForNextLevel - gameProfile.currentXP) XP"),
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
                                .glassCard(cornerRadius: AppTheme.cornerRadiusMedium)
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
                                    .font(.app(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(AppTheme.paddingMedium)
                            .glassCard(cornerRadius: AppTheme.cornerRadiusMedium)
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
            .background(AppScreenBackground())
            #if DEBUG
            .onAppear {
                // Screenshot hook: -ScrollToTree
                if ProcessInfo.processInfo.arguments.contains("-ScrollToTree") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { proxy.scrollTo("wealthTree", anchor: .top) }
                }
            }
            #endif
            }
        }
    }
}

extension GamificationHubView {
    /// The reason this tab exists: every active quest, grouped daily/weekly, with live progress.
    @ViewBuilder
    fileprivate func questsList(gameProfile: GameProfile) -> some View {
        let daily = gameProfile.quests.filter { $0.isDaily && !$0.isExpired }
        let weekly = gameProfile.quests.filter { !$0.isDaily && !$0.isExpired }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if !daily.isEmpty {
                    Text("\(daily.filter(\.isCompleted).count)/\(daily.count) done")
                        .font(AppTheme.smallFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            if daily.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppTheme.primaryGreen)
                    Text("New quests arrive tomorrow")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(AppTheme.paddingMedium)
                .glassCard(cornerRadius: AppTheme.cornerRadiusMedium)
                .padding(.horizontal, AppTheme.paddingLarge)
            } else {
                ForEach(daily, id: \.id) { quest in
                    QuestQuickView(quest: quest)
                        .padding(.horizontal, AppTheme.paddingLarge)
                        .scrollDepth()
                }
            }

            if !weekly.isEmpty {
                Text("This Week")
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .padding(.horizontal, AppTheme.paddingLarge)
                    .padding(.top, 4)

                ForEach(weekly, id: \.id) { quest in
                    QuestQuickView(quest: quest)
                        .padding(.horizontal, AppTheme.paddingLarge)
                        .scrollDepth()
                }
            }
        }
    }
}

// MARK: - Stat Tile Component

struct StatTile: View {
    let label: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.app(size: 18, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.app(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)

            Text(label)
                .font(.app(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: AppTheme.cornerRadiusMedium)
    }
}

// MARK: - Quest Quick View

struct QuestQuickView: View {
    let quest: Quest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quest.displayTitle)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.app(size: 10))
                            Text("\(quest.difficulty.baseXP) XP")
                                .font(AppTheme.smallFont)
                        }
                        .foregroundColor(AppTheme.accentGold)

                        Text(quest.progressDisplay)
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(quest.isCompleted ? AppTheme.primaryGreen : .clear)
                    Circle()
                        .strokeBorder(quest.isCompleted ? .clear : AppTheme.textTertiary, lineWidth: 1.5)
                    DrawnCheckmark(isOn: quest.isCompleted, color: AppTheme.background, lineWidth: 2.5)
                        .padding(5.5)
                }
                .frame(width: 22, height: 22)
                .animation(.spring(duration: 0.35), value: quest.isCompleted)
                .accessibilityHidden(true)
            }

            if quest.targetValue > 0 {
                let progress = min(1.0, quest.currentProgress / quest.targetValue)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.cardBackgroundLight)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.primaryGreen)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(AppTheme.paddingMedium)
        .glassCard(cornerRadius: AppTheme.cornerRadiusMedium)
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
                    .font(.app(size: 24, weight: .semibold))
                    .foregroundColor(badge.rarity.foregroundColor)
            }
            .frame(height: 70)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(badge.rarity.borderColor, lineWidth: 1.5)
            )

            Text(LocalizedStringKey(badge.badgeID.rawValue))
                .font(.app(size: 10, weight: .semibold))
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
