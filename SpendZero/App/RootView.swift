import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showSplash = true
    @State private var showStrategicPaywall = false
    @State private var subscriptionService = SubscriptionService.shared

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            Group {
                if !hasCompletedOnboarding {
                    // Step 1: Onboarding → ends by setting hasCompletedOnboarding = true
                    OnboardingFlowView()
                } else if let profile, !profile.hasStartedTrial {
                    // Step 2: First time after onboarding — show soft paywall + start trial
                    PaywallView(
                        onContinue: { startTrial(for: profile) },
                        urgencyMessage: "Start your 3-day free trial — full access, no charge"
                    )
                } else if let profile, profile.isTrialExpired, !subscriptionService.isPremium {
                    // Step 3: Trial expired + not paid — HARD PAYWALL (no X button)
                    PaywallView(
                        onContinue: { /* only reachable via successful purchase */ },
                        isHardPaywall: true,
                        urgencyMessage: hardPaywallMessage(for: profile)
                    )
                } else {
                    // Step 4: Trial active OR premium → full app access
                    MainTabView()
                        .sheet(isPresented: $showStrategicPaywall) {
                            PaywallView(
                                onContinue: { showStrategicPaywall = false },
                                urgencyMessage: strategicPaywallMessage
                            )
                        }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Ensure existing users have a GameProfile (with seeded quests)
            if let profile, profile.gameProfile == nil {
                let gp = GameProfile()
                modelContext.insert(gp)
                profile.gameProfile = gp
                let dailies = GameStateManager.shared.generateDailyQuests(for: gp)
                let weekly  = GameStateManager.shared.generateWeeklyQuest(for: gp)
                gp.quests.append(contentsOf: dailies)
                gp.quests.append(weekly)
                try? modelContext.save()
            }

            // Refresh quests for any returning user (handles daily/weekly rollover)
            if let gp = profile?.gameProfile {
                GameStateManager.shared.refreshQuestsIfNeeded(for: gp)
                try? modelContext.save()
            }

            // Reconcile the streak against the calendar: break it (or spend a freeze)
            // if a day was missed. Stash the outcome so the Dashboard can surface it.
            if let profile {
                switch profile.reconcileStreak() {
                case .frozen(let days):
                    UserDefaults.standard.set("frozen:\(days)", forKey: "pendingStreakEvent")
                case .lapsed(let lost):
                    UserDefaults.standard.set("lapsed:\(lost)", forKey: "pendingStreakEvent")
                case .intact:
                    break
                }
                try? modelContext.save()
                NotificationManager.shared.refreshRetentionNotifications(
                    currentStreak: profile.currentStreak,
                    loggedToday: profile.hasLoggedToday()
                )
            }

            // Keep the Home Screen widget in sync with the latest progress
            WidgetSync.refresh(profile: profile, context: modelContext)

            // Dismiss splash — kept short so launch feels snappy (was 2.2s dead time
            // on every cold launch regardless of how fast the app was actually ready).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
                // After splash, check for strategic paywall nudge
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    checkStrategicPaywall()
                }
            }
        }
        .task {
            // Re-check premium status on every app launch
            await subscriptionService.checkEntitlementStatus()
        }
    }

    // MARK: - Trial Management

    private func startTrial(for profile: UserProfile) {
        profile.trialStartDate = Date()
        try? modelContext.save()
    }

    // MARK: - Hard Paywall Copy

    /// Loss-aversion framing for the post-trial hard paywall, using what the user
    /// actually built so they feel the cost of walking away.
    private func hardPaywallMessage(for profile: UserProfile) -> String {
        if profile.currentStreak > 0 && profile.totalSaved > 0 {
            return "Your trial ended — don't lose your \(profile.currentStreak)-day streak and \(profile.totalSaved.currencyFormatted) saved."
        } else if profile.currentStreak > 0 {
            return "Your trial ended — keep your \(profile.currentStreak)-day streak alive."
        } else if profile.totalSaved > 0 {
            return "Your trial ended — keep building on the \(profile.totalSaved.currencyFormatted) you've saved."
        }
        return "Your free trial has ended"
    }

    // MARK: - Strategic Paywall (day 2, day 3 nudges)

    private var strategicPaywallMessage: String? {
        guard let profile else { return nil }
        if profile.isTrialExpired { return "Your free trial has ended" }
        let remaining = profile.trialDaysRemaining
        if remaining <= 1 { return "Trial expires today — don't lose your progress!" }
        if remaining == 2 { return "Trial ends tomorrow — lock in your savings" }
        return nil
    }

    private func checkStrategicPaywall() {
        guard let profile, !subscriptionService.isPremium else { return }
        guard profile.hasStartedTrial, profile.isTrialActive else { return }
        guard profile.shouldShowPaywallNudge else { return }

        // Mark that we showed paywall today
        profile.lastPaywallShownDate = Date()
        try? modelContext.save()

        showStrategicPaywall = true
    }
}

// MARK: - Animated Splash Screen

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Radial glow behind logo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.primaryGreen.opacity(0.25),
                            AppTheme.primaryGreen.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .opacity(glowOpacity)

            VStack(spacing: 24) {
                // Brand icon from asset catalog
                Image("BrandIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: AppTheme.primaryGreen.opacity(0.4), radius: 20, y: 8)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("SpendZero")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Build Financial Freedom")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen)
                }
                .opacity(titleOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                glowOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                titleOpacity = 1.0
            }
        }
    }
}
