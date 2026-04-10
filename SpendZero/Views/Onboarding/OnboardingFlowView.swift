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

            TabView(selection: $currentStep) {
                OnboardingSplashView(onNext: nextStep)
                    .tag(0)

                OnboardingNameView(name: $userName, onNext: nextStep)
                    .tag(1)

                OnboardingSpendingQuizView(level: $spendingLevel, onNext: nextStep)
                    .tag(2)

                OnboardingCategoriesView(selected: $selectedCategories, onNext: nextStep)
                    .tag(3)

                OnboardingCommitView(days: $challengeDays, onNext: nextStep)
                    .tag(4)

                OnboardingLoadingView(
                    userName: userName,
                    onComplete: nextStep
                )
                .tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.5), value: currentStep)

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
        if currentStep < 5 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        let profile = UserProfile(
            displayName: userName,
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

        try? modelContext.save()
        hasCompletedOnboarding = true
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
