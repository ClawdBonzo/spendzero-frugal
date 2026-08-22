import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @State private var userName = ""
    @State private var spendingLevel: SpendingLevel = .moderate
    @State private var selectedCategories: Set<SpendCategory> = []
    @State private var challengeDays = 30
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    private let totalSteps = 6

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Steps are driven only by their Continue buttons: a paging TabView would let the
            // user swipe past the name / categories gates, so each step is shown on its own
            // and slides in when `currentStep` advances.
            Group {
                switch currentStep {
                case 0:
                    OnboardingSplashView(onNext: nextStep)
                case 1:
                    OnboardingNameView(name: $userName, onNext: nextStep)
                case 2:
                    OnboardingSpendingQuizView(level: $spendingLevel, onNext: nextStep)
                case 3:
                    OnboardingCategoriesView(selected: $selectedCategories, onNext: nextStep)
                case 4:
                    OnboardingCommitView(days: $challengeDays, onNext: nextStep)
                default:
                    OnboardingLoadingView(
                        userName: userName.trimmingCharacters(in: .whitespacesAndNewlines),
                        challengeDays: challengeDays,
                        onComplete: nextStep
                    )
                }
            }
            .id(currentStep)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)))
            .animation(.easeInOut(duration: 0.4), value: currentStep)
            .onChange(of: currentStep) { _, _ in
                // Dismiss the keyboard whenever we move between steps so it never
                // lingers over a later screen or covers its Continue button.
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            // Progress indicator
            if currentStep > 0 && currentStep < 5 {
                VStack {
                    OnboardingProgressBar(current: currentStep, total: totalSteps)
                        .padding(.top, 8)
                    Spacer()
                }
            }
        }
    }

    private func nextStep() {
        // The name step can't be skipped with an empty name.
        if currentStep == 1, userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        if currentStep < 5 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = UserProfile(
            displayName: trimmedName.isEmpty ? String(localized: "Champion") : trimmedName,
            dailyBudget: spendingLevel.dailyEstimate,
            challengeDays: challengeDays,
            spendingLevel: spendingLevel,
            leakCategories: selectedCategories.map(\.rawValue)
        )
        modelContext.insert(profile)

        // Create and attach GameProfile — required for Dashboard, Quests, and gamification
        let gameProfile = GameProfile()
        modelContext.insert(gameProfile)
        profile.gameProfile = gameProfile

        // Seed initial quests so the Quests tab isn't empty on day one
        let dailies = GameStateManager.shared.generateDailyQuests()
        let weekly  = GameStateManager.shared.generateWeeklyQuest()
        gameProfile.quests.append(contentsOf: dailies)
        gameProfile.quests.append(weekly)

        // Welcome bonus: a little starting XP so the level card and money tree show
        // immediate progress instead of a deflating literal zero on first open.
        gameProfile.totalXPEarned += 100
        gameProfile.currentXP += 100

        // Trial not started yet — will start when user dismisses the first paywall
        // (or purchases). This way onboarding completion doesn't waste trial time.

        try? modelContext.save()
        hasCompletedOnboarding = true

        // Prime notifications at the moment of peak commitment (right after the user
        // chose their challenge), then arm the streak-protection reminders. Without
        // this, the only opt-in was buried in Settings, so almost no one enabled them.
        Task { @MainActor in
            let granted = await NotificationManager.shared.requestAuthorization()
            if granted {
                // Keep Settings in sync so its toggle reflects what's actually scheduled.
                UserDefaults.standard.set(true, forKey: "impulseAlertsEnabled")
                UserDefaults.standard.set(19, forKey: "impulseAlertHour")
                NotificationManager.shared.scheduleDailyReminder(hour: 19)
                NotificationManager.shared.refreshRetentionNotifications(currentStreak: 0, loggedToday: false)
            }
        }
    }
}

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1..<total, id: \.self) { step in
                Capsule()
                    .fill(step <= current ? AppTheme.primaryGreen : AppTheme.textTertiary.opacity(0.3))
                    .frame(height: 4)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
        .padding(.horizontal, AppTheme.paddingLarge)
    }
}
