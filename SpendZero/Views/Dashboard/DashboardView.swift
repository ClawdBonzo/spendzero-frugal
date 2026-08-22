import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Predicated queries: only today's records/savings and the last 30 days of impulses.
    @Query private var dailyRecords: [DailyRecord]
    @Query private var todaySavings: [SavingsEntry]
    @Query private var impulses: [ImpulseLog]
    @State private var showAddImpulse = false
    @State private var impulseToDelete: ImpulseLog?
    @State private var showGamificationHub = false
    @State private var showUpgradePaywall = false
    @State private var subscription = SubscriptionService.shared
    @State private var spentTodayBlock = false
    // Staggered entrance animation
    @State private var showGreeting = false
    @State private var showLevelCard = false
    @State private var showStreakCard = false
    @State private var showStats = false
    @State private var showActions = false
    @State private var streakBadgePulse = false

    private var profile: UserProfile? { profiles.first }
    private var gameProfile: GameProfile? { profile?.gameProfile }

    init() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let monthAgo = cal.date(byAdding: .day, value: -30, to: start) ?? start
        _dailyRecords = Query(filter: #Predicate<DailyRecord> { $0.date >= start && $0.date < end },
                              sort: \DailyRecord.date, order: .reverse)
        _todaySavings = Query(filter: #Predicate<SavingsEntry> { $0.date >= start && $0.date < end },
                              sort: \SavingsEntry.date, order: .reverse)
        _impulses = Query(filter: #Predicate<ImpulseLog> { $0.date >= monthAgo },
                          sort: \ImpulseLog.date, order: .reverse)
    }

    private var todayRecord: DailyRecord? { dailyRecords.first }

    private var currentStreak: Int {
        profile?.currentStreak ?? 0
    }

    /// The engine keeps `profile.totalSaved` in sync with every savings change.
    private var totalSaved: Double { profile?.totalSaved ?? 0 }

    private var todaySaved: Double {
        todaySavings.reduce(0) { $0 + $1.amount }
    }

    private var impulsesResistedToday: Int {
        todayRecord?.impulsesResisted ?? 0
    }

    /// A user who has never logged anything yet — gets an encouraging first-action
    /// card instead of a deflating wall of zeros.
    private var isBrandNewUser: Bool {
        currentStreak == 0 && totalSaved == 0 && profile?.lastNoSpendDate == nil
            && dailyRecords.isEmpty && impulses.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient money particle background (throttled, respects reduceMotion).
                // Lives inside the navigation root so pushed screens cover it.
                ParticleBackgroundView(count: 8)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Greeting — slides in from left
                        greetingSection
                            .offset(x: showGreeting ? 0 : -40)
                            .opacity(showGreeting ? 1 : 0)

                        // Trial countdown banner
                        if let profile, profile.isTrialActive, !subscription.isPremium {
                            trialBanner(daysLeft: profile.trialDaysRemaining)
                                .offset(y: showGreeting ? 0 : -10)
                                .opacity(showGreeting ? 1 : 0)
                        }

                        // Level progress hero — scales in
                        if let gameProfile = gameProfile {
                            LevelCard(gameProfile: gameProfile, currentStreak: currentStreak)
                                .padding(.horizontal, AppTheme.paddingMedium)
                                .scaleEffect(showLevelCard ? 1 : 0.9)
                                .opacity(showLevelCard ? 1 : 0)
                        }

                        // Streak hero card — slides up (welcome CTA for brand-new users)
                        Group {
                            if isBrandNewUser {
                                welcomeStartCard
                            } else {
                                streakHeroCard
                            }
                        }
                        .offset(y: showStreakCard ? 0 : 30)
                        .opacity(showStreakCard ? 1 : 0)

                        // Money Tree visualization
                        if let gameProfile = gameProfile {
                            MoneyTreeView(gameProfile: gameProfile)
                                .padding(.horizontal, AppTheme.paddingMedium)
                                .offset(y: showStats ? 0 : 25)
                                .opacity(showStats ? 1 : 0)
                        }

                        // Quick stats — staggered scale
                        quickStatsGrid
                            .offset(y: showStats ? 0 : 20)
                            .opacity(showStats ? 1 : 0)

                        // Quest quick-access
                        if let gameProfile = gameProfile, !gameProfile.quests.isEmpty {
                            questQuickLink
                                .padding(.horizontal, AppTheme.paddingMedium)
                                .offset(y: showActions ? 0 : 20)
                                .opacity(showActions ? 1 : 0)
                        }

                        // Today's status
                        todayStatusCard
                            .offset(y: showActions ? 0 : 20)
                            .opacity(showActions ? 1 : 0)

                        // Recent impulses
                        if !impulses.prefix(3).isEmpty {
                            recentImpulsesSection
                                .offset(y: showActions ? 0 : 20)
                                .opacity(showActions ? 1 : 0)
                        }

                        // Quick actions
                        quickActionsSection
                            .offset(y: showActions ? 0 : 20)
                            .opacity(showActions ? 1 : 0)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, AppTheme.paddingMedium)
                    .padding(.top, 8)
                    .onAppear { triggerEntranceAnimations() }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddImpulse) {
                AddImpulseView()
            }
            .confirmationDialog(Text("Delete this impulse?"), isPresented: Binding(
                get: { impulseToDelete != nil }, set: { if !$0 { impulseToDelete = nil } }
            ), titleVisibility: .visible, presenting: impulseToDelete) { impulse in
                Button(role: .destructive) { deleteImpulse(impulse) } label: { Text("Delete") }
                Button(role: .cancel) { impulseToDelete = nil } label: { Text("Cancel") }
            } message: { _ in
                Text("Any savings credited for it will be removed.")
            }
        }
        .onAppear { refreshTodayState() }
        .onChange(of: dailyRecords.count) { _, _ in refreshTodayState() }
        .onReceive(NotificationCenter.default.publisher(for: .spendZeroPerformAction)) { note in
            if note.object as? AppAction == .logImpulse { showAddImpulse = true }
        }
    }

    /// Whether the "Mark Win" button should be live, and what it should say.
    private var noSpendDayBlocker: ProgressEngine.NoSpendDayBlocker? {
        guard let profile else { return nil }
        if profile.hasLoggedToday() { return .alreadyLogged }
        return spentTodayBlock ? .spentToday : nil
    }

    private func refreshTodayState() {
        spentTodayBlock = ProgressEngine.shared.hasNonEssentialSpending(on: Date(), context: modelContext)
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 8) {
                    Text(profile?.displayName ?? String(localized: "Champion"))
                        .font(AppTheme.titleFont)
                        .foregroundColor(AppTheme.textPrimary)

                    if let gameProfile = gameProfile {
                        NavigationLink {
                            LevelProgressView(gameProfile: gameProfile)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Lv. \(gameProfile.currentLevel)")
                                    .font(.app(size: 12, weight: .semibold))
                                Text(gameProfile.currentRank.title)
                                    .font(.app(size: 10, weight: .semibold))
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

            // Streak badge — pulsing glow
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 2)
                    .frame(width: 62, height: 62)
                    .scaleEffect(streakBadgePulse ? 1.15 : 0.95)
                    .opacity(streakBadgePulse ? 0.0 : 0.8)
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.8).repeatForever(autoreverses: false),
                               value: streakBadgePulse)

                Circle()
                    .fill(AppTheme.primaryGreen.opacity(0.15))
                    .frame(width: 52, height: 52)

                VStack(spacing: 0) {
                    Text("\(currentStreak)")
                        .font(.app(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen)
                        .contentTransition(.numericText())
                    Text("days")
                        .font(.app(size: 9, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Welcome / Empty State (brand-new user)

    private var welcomeStartCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGreen.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "flag.checkered")
                    .font(.app(size: 30, weight: .semibold))
                    .foregroundColor(AppTheme.primaryGreen)
            }

            VStack(spacing: 4) {
                Text("Your journey starts today")
                    .font(AppTheme.headlineFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Log your first no-spend day to start your streak and earn +100 XP.")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                HapticManager.shared.trigger(.celebrate)
                markNoSpendDay()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Mark Today a No-Spend Day")
                        .font(.app(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(AppTheme.paddingLarge)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusXL)
                        .stroke(AppTheme.primaryGreen.opacity(0.25), lineWidth: 1)
                )
        )
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
                            .font(.app(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primaryGreen)
                            .contentTransition(.numericText(countsDown: false))
                            .animation(.spring(response: 0.5), value: currentStreak)
                            .accessibilityLabel("\(currentStreak) day streak")

                        Text("days")
                            .font(AppTheme.headlineFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    StreakFlamesView(currentStreak: currentStreak)
                        .font(.app(size: 24))

                    // Streak freezes — the safety net that protects a missed day.
                    if let freezes = profile?.streakFreezes, freezes > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "snowflake")
                                .font(.app(size: 11, weight: .bold))
                            Text("\(freezes)")
                                .font(.app(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "60CFFF"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "60CFFF").opacity(0.12))
                        .clipShape(Capsule())
                        .accessibilityLabel("\(freezes) streak freezes available")
                    }

                    // One-tap viral share button
                    if currentStreak > 0 {
                        ShareStreakButton(
                            streak: currentStreak,
                            name: profile?.displayName ?? "",
                            totalSaved: totalSaved
                        )
                    }
                }
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
                value: todaySaved.currencyFormatted,
                icon: "dollarsign.circle.fill",
                color: AppTheme.primaryGreen
            )

            StatCard(
                title: "Total Saved",
                value: totalSaved.currencyFormatted,
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

                let isNoSpend = !spentTodayBlock
                HStack(spacing: 6) {
                    Circle()
                        .fill(isNoSpend ? AppTheme.primaryGreen : AppTheme.destructive)
                        .frame(width: 8, height: 8)
                    Text(isNoSpend ? (noSpendDayBlocker == .alreadyLogged ? "No-Spend Day ✓" : "No Spending Yet") : "Spent Today")
                        .font(AppTheme.captionFont)
                        .foregroundColor(isNoSpend ? AppTheme.primaryGreen : AppTheme.destructive)
                }
            }

            HStack(spacing: 12) {
                TodayActionButton(icon: "bolt.slash.fill", title: "Log Impulse", color: AppTheme.warning) {
                    HapticManager.shared.trigger(.sheetPresented)
                    showAddImpulse = true
                }

                switch noSpendDayBlocker {
                case .alreadyLogged:
                    TodayActionButton(icon: "checkmark.seal.fill", title: "Logged ✓", color: AppTheme.textSecondary) {
                        HapticManager.shared.trigger(.toggleOff)
                    }
                    .disabled(true)
                case .spentToday:
                    TodayActionButton(icon: "xmark.seal", title: "Spent Today", color: AppTheme.textSecondary) {
                        HapticManager.shared.trigger(.warning)
                    }
                    .disabled(true)
                case nil:
                    TodayActionButton(icon: "checkmark.seal.fill", title: "Mark Win", color: AppTheme.primaryGreen) {
                        markNoSpendDay()
                    }
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
                            .font(.app(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(LocalizedStringKey(impulse.category.rawValue))
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    Spacer()

                    Text(impulse.estimatedCost.currencyFormatted)
                        .font(.app(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(impulse.wasResisted ? AppTheme.primaryGreen : AppTheme.destructive)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(AppTheme.cardBackground)
                )
                .contextMenu {
                    Button(role: .destructive) { impulseToDelete = impulse } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func deleteImpulse(_ impulse: ImpulseLog) {
        ProgressEngine.shared.deleteImpulse(impulse, profile: profile, context: modelContext)
        impulseToDelete = nil
        EventPresenter.shared.enqueue(.info(String(localized: "Impulse deleted")))
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
                            .font(.app(size: 10))
                        Text("Earn XP")
                            .font(AppTheme.smallFont)
                    }
                    .foregroundColor(AppTheme.primaryGreen)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.app(size: 12, weight: .semibold))
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
                    ProgressChartsView()
                } label: {
                    QuickActionCard(icon: "chart.line.uptrend.xyaxis", title: "Progress", color: AppTheme.primaryGreen)
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

    private func trialBanner(daysLeft: Int) -> some View {
        Button {
            HapticManager.shared.trigger(.buttonTap)
            showUpgradePaywall = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: daysLeft <= 1 ? "exclamationmark.triangle.fill" : "clock.fill")
                    .font(.app(size: 14, weight: .semibold))
                    .foregroundColor(daysLeft <= 1 ? AppTheme.accentGold : AppTheme.primaryGreen)

                VStack(alignment: .leading, spacing: 1) {
                    Text(daysLeft <= 1 ? "Last free day" : "Free access: \(daysLeft) days left")
                        .font(.app(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Tap to upgrade and keep your progress")
                        .font(.app(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Text("Upgrade")
                    .font(.app(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.primaryGreen)
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(daysLeft <= 1
                        ? AppTheme.accentGold.opacity(0.1)
                        : AppTheme.primaryGreen.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                            .stroke(daysLeft <= 1
                                ? AppTheme.accentGold.opacity(0.3)
                                : AppTheme.primaryGreen.opacity(0.2),
                                lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showUpgradePaywall) {
            PaywallView(
                onContinue: { showUpgradePaywall = false },
                urgencyMessage: daysLeft <= 1
                    ? "Last free day — don't lose your streak!"
                    : "Lock in your savings before free access ends"
            )
        }
    }

    private func triggerEntranceAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
            showGreeting = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15)) {
            showLevelCard = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
            showStreakCard = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35)) {
            showStats = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.45)) {
            showActions = true
        }
        // Start streak badge pulse loop (skipped when Reduce Motion is on)
        guard !reduceMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            streakBadgePulse = true
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "Good morning")
        case 12..<17: return String(localized: "Good afternoon")
        case 17..<21: return String(localized: "Good evening")
        default: return String(localized: "Good night")
        }
    }

    private func markNoSpendDay() {
        guard let profile else { return }
        guard let outcome = ProgressEngine.shared.logNoSpendDay(profile: profile, context: modelContext) else {
            HapticManager.shared.trigger(.warning)
            refreshTodayState()
            return
        }
        HapticManager.shared.trigger(.celebrate)
        EventPresenter.shared.present(outcome,
                                      primary: .nospendDayRecorded(xp: outcome.xpGranted),
                                      rank: profile.gameProfile?.currentRank)
        refreshTodayState()
    }
}

// MARK: - Subviews

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.app(size: 20))
                .foregroundColor(color)
                .symbolEffect(.pulse, value: reduceMotion ? false : appeared)

            Text(value)
                .font(.app(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .contentTransition(.numericText())

            Text(title)
                .font(.app(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.cardBackground)
        )
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}

struct TodayActionButton: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.app(size: 16))
                Text(title)
                    .font(.app(size: 14, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(color.opacity(0.12))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: LocalizedStringKey
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.app(size: 24))
                .foregroundColor(color)

            Text(title)
                .font(.app(size: 13, weight: .semibold))
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
