import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyRecord.date, order: .reverse) private var dailyRecords: [DailyRecord]
    @Query(sort: \SavingsEntry.date, order: .reverse) private var savings: [SavingsEntry]
    @Query(sort: \ImpulseLog.date, order: .reverse) private var impulses: [ImpulseLog]
    @State private var showAddImpulse = false
    @State private var showGamificationHub = false
    @State private var currentToast: GameEventType?
    @State private var levelUpEvent: (newLevel: Int, rank: LevelRank, previousLevel: Int)?
    @State private var badgeUnlockEvent: BadgeInstance?

    private var profile: UserProfile? { profiles.first }
    private var gameProfile: GameProfile? { profile?.gameProfile ?? GameProfile() }

    private var todayRecord: DailyRecord? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyRecords.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var currentStreak: Int {
        profile?.currentStreak ?? 0
    }

    private var totalSaved: Double {
        savings.reduce(0) { $0 + $1.amount }
    }

    private var todaySaved: Double {
        let today = Calendar.current.startOfDay(for: Date())
        return savings
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            .reduce(0) { $0 + $1.amount }
    }

    private var impulsesResistedToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return impulses
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) && $0.wasResisted }
            .count
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Greeting
                        greetingSection

                        // Level progress hero (PROMINENT)
                        if let gameProfile = gameProfile {
                            LevelCard(gameProfile: gameProfile, currentStreak: currentStreak)
                                .padding(.horizontal, AppTheme.paddingMedium)
                        }

                        // Streak hero card
                        streakHeroCard

                        // Money Tree visualization
                        if let gameProfile = gameProfile {
                            MoneyTreeView(gameProfile: gameProfile)
                                .padding(.horizontal, AppTheme.paddingMedium)
                        }

                        // Quick stats
                        quickStatsGrid

                        // Quest quick-access
                        if let gameProfile = gameProfile, !gameProfile.quests.isEmpty {
                            questQuickLink
                                .padding(.horizontal, AppTheme.paddingMedium)
                        }

                        // Today's status
                        todayStatusCard

                        // Recent impulses
                        if !impulses.prefix(3).isEmpty {
                            recentImpulsesSection
                        }

                        // Quick actions
                        quickActionsSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, AppTheme.paddingMedium)
                    .padding(.top, 8)
                }
                .background(AppTheme.background.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showAddImpulse) {
                    AddImpulseView(onImpulseLogged: { recordImpulseLogged() })
                }
            }

            // Toast notifications
            VStack(spacing: 12) {
                if let toast = currentToast {
                    GameEventToastView(event: toast, onDismiss: { currentToast = nil })
                }
                Spacer()
            }
            .padding()

            // Celebration overlays
            if let (newLevel, rank, previousLevel) = levelUpEvent {
                LevelUpCelebrationView(
                    newLevel: newLevel,
                    rank: rank,
                    previousLevel: previousLevel,
                    onDismiss: { levelUpEvent = nil }
                )
            }

            if let badge = badgeUnlockEvent {
                BadgeUnlockCelebrationView(
                    badge: badge,
                    onDismiss: { badgeUnlockEvent = nil }
                )
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 8) {
                    Text(profile?.displayName ?? "Champion")
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.textPrimary)

                    if let gameProfile = gameProfile {
                        NavigationLink {
                            LevelProgressView(gameProfile: gameProfile)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Lv. \(gameProfile.currentLevel)")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(gameProfile.currentRank.title)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(AppTheme.accentGold)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(AppTheme.accentGold.opacity(0.15))
                            .cornerRadius(6)
                        }
                    }
                }
            }

            Spacer()

            // Streak badge
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGreen.opacity(0.15))
                    .frame(width: 52, height: 52)

                VStack(spacing: 0) {
                    Text("\(currentStreak)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen)
                    Text("days")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Streak Hero

    private var streakHeroCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Streak")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(currentStreak)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primaryGreen)

                        Text("days")
                            .font(AppTheme.headlineFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                StreakFlamesView(currentStreak: currentStreak)
                    .font(.system(size: 24))
            }

            // Progress bar to goal
            if let profile {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Goal: \(profile.challengeDays) days")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        Text("\(Int(Double(currentStreak) / Double(profile.challengeDays) * 100))%")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryGreen)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.cardBackgroundLight)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.primaryGradient)
                                .frame(width: geo.size.width * min(1.0, Double(currentStreak) / Double(profile.challengeDays)))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(AppTheme.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL)
                        .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Quick Stats

    private var quickStatsGrid: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Saved Today",
                value: "$\(Int(todaySaved))",
                icon: "dollarsign.circle.fill",
                color: AppTheme.primaryGreen
            )

            StatCard(
                title: "Total Saved",
                value: "$\(Int(totalSaved))",
                icon: "banknote.fill",
                color: AppTheme.accentGold
            )

            StatCard(
                title: "Resisted",
                value: "\(impulsesResistedToday)",
                icon: "bolt.slash.fill",
                color: AppTheme.info
            )
        }
    }

    // MARK: - Today Status

    private var todayStatusCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Today's Status")
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()

                let isNoSpend = todayRecord?.isNoSpendDay ?? true
                HStack(spacing: 6) {
                    Circle()
                        .fill(isNoSpend ? AppTheme.primaryGreen : AppTheme.destructive)
                        .frame(width: 8, height: 8)
                    Text(isNoSpend ? "No-Spend Day" : "Spent Today")
                        .font(AppTheme.captionFont)
                        .foregroundColor(isNoSpend ? AppTheme.primaryGreen : AppTheme.destructive)
                }
            }

            HStack(spacing: 12) {
                TodayActionButton(icon: "bolt.slash.fill", title: "Log Impulse", color: AppTheme.warning) {
                    showAddImpulse = true
                }

                TodayActionButton(icon: "checkmark.seal.fill", title: "Mark Win", color: AppTheme.primaryGreen) {
                    markNoSpendDay()
                }
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.cardBackground)
        )
    }

    // MARK: - Recent Impulses

    private var recentImpulsesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Impulses")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(Array(impulses.prefix(3))) { impulse in
                HStack(spacing: 12) {
                    Image(systemName: impulse.wasResisted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(impulse.wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(impulse.item)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(impulse.category.rawValue)
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Text("$\(Int(impulse.estimatedCost))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(impulse.wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(AppTheme.cardBackground)
                )
            }
        }
    }

    // MARK: - Quest Quick Link

    private var questQuickLink: some View {
        NavigationLink {
            if let gameProfile = gameProfile {
                QuestPanelView(gameProfile: gameProfile)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Quests")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Earn XP")
                            .font(AppTheme.smallFont)
                    }
                    .foregroundColor(AppTheme.primaryGreen)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(AppTheme.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(AppTheme.cardBackground)
            )
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 12) {
                NavigationLink {
                    ChallengeLibraryView()
                } label: {
                    QuickActionCard(icon: "trophy.fill", title: "Challenges", color: AppTheme.accentGold)
                }

                NavigationLink {
                    ExportView()
                } label: {
                    QuickActionCard(icon: "doc.text.fill", title: "Export", color: AppTheme.info)
                }
            }
        }
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private func markNoSpendDay() {
        let today = Calendar.current.startOfDay(for: Date())
        if todayRecord == nil {
            let record = DailyRecord(date: today, isNoSpendDay: true)
            modelContext.insert(record)

            let saving = SavingsEntry(
                amount: profile?.dailyBudget ?? 50,
                source: .noSpendDay,
                note: "No-spend day completed!"
            )
            modelContext.insert(saving)

            if let profile {
                profile.currentStreak += 1
                if profile.currentStreak > profile.longestStreak {
                    profile.longestStreak = profile.currentStreak
                }
                profile.totalSaved += saving.amount
            }

            try? modelContext.save()

            // Award XP
            if let gameProfile = gameProfile {
                let streak = currentStreak
                let multiplier = GameStateManager.shared.calculateStreakMultiplier(streak: streak)
                let result = gameProfile.grantXP(.noSpendDay, streak: streak, multiplier: multiplier)

                // Show toast
                currentToast = .nospendDayRecorded

                // Check for level up
                if result.leveledUp {
                    let previousLevel = result.newLevel - 1
                    levelUpEvent = (result.newLevel, gameProfile.currentRank, previousLevel)
                }

                // Check for streak badge
                let newBadges = GameStateManager.shared.checkStreakBadges(
                    for: gameProfile,
                    currentStreak: streak
                )
                if let firstBadge = newBadges.first,
                   let badgeInstance = gameProfile.badges.first(where: { $0.badgeID == firstBadge }) {
                    badgeUnlockEvent = badgeInstance
                }

                try? modelContext.save()
            }
        }
    }

    private func recordImpulseLogged() {
        // Award XP when an impulse is logged
        if let gameProfile = gameProfile {
            let streak = currentStreak
            let multiplier = GameStateManager.shared.calculateStreakMultiplier(streak: streak)
            let result = gameProfile.grantXP(.impulseResisted, streak: streak, multiplier: multiplier)

            currentToast = .nospendDayRecorded

            if result.leveledUp {
                let previousLevel = result.newLevel - 1
                levelUpEvent = (result.newLevel, gameProfile.currentRank, previousLevel)
            }

            try? modelContext.save()
        }
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.cardBackground)
        )
    }
}

struct TodayActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(color.opacity(0.12))
            )
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.cardBackground)
        )
    }
}
