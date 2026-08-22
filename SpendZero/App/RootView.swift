import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showSplash = true
    @State private var showStrategicPaywall = false
    @State private var subscriptionService = SubscriptionService.shared
    @Environment(\.scenePhase) private var scenePhase

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ZStack {
            Group {
                if !hasCompletedOnboarding {
                    // Step 1: Onboarding → ends by setting hasCompletedOnboarding = true
                    OnboardingFlowView()
                } else if let profile, !profile.hasStartedTrial, !subscriptionService.isPremium {
                    // Step 2: First time after onboarding — soft paywall; closing it starts the
                    // 3-day full-access window. Subscribers (e.g. reinstalling) skip it.
                    PaywallView(
                        onContinue: { startTrial(for: profile) },
                        urgencyMessage: "Not ready? Close this and use everything free for 3 days."
                    )
                } else if let profile, profile.hasStartedTrial, profile.isTrialExpired, !subscriptionService.isPremium {
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
            activate()

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
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !showSplash else { return }
            activate()
            Task { await subscriptionService.checkEntitlementStatus() }
        }
        .task {
            // Re-check premium status on every app launch
            await subscriptionService.checkEntitlementStatus()
        }
    }

    /// Runs on launch and every return to the foreground: streak reconcile, quest rollover,
    /// pending widget marks, widget + notification refresh.
    private func activate() {
        guard let profile else { return }
        let outcome = ProgressEngine.shared.reconcileOnActivate(profile: profile, context: modelContext)
        // A freeze being spent is a positive moment worth surfacing; a lapse is not (the
        // lapse notification already nudged them, and a scold on open reads badly).
        let delay: Double = showSplash ? 2.2 : 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if !outcome.isEmpty || { if case .frozen = outcome.streakOutcome { return true }; return false }() {
                EventPresenter.shared.present(outcome,
                                              primary: outcome.newStreak != nil ? .nospendDayRecorded(xp: outcome.xpGranted) : nil,
                                              rank: profile.gameProfile?.currentRank)
            }
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
            return "Your 3 free days are up — don't lose your \(profile.currentStreak)-day streak and \(profile.totalSaved.currencyFormatted) saved."
        } else if profile.currentStreak > 0 {
            return "Your 3 free days are up — keep your \(profile.currentStreak)-day streak alive."
        } else if profile.totalSaved > 0 {
            return "Your 3 free days are up — keep building on the \(profile.totalSaved.currencyFormatted) you've saved."
        }
        return "Your 3 free days are up"
    }

    // MARK: - Strategic Paywall (day 2, day 3 nudges)

    private var strategicPaywallMessage: String? {
        guard let profile else { return nil }
        if profile.isTrialExpired { return "Your 3 free days are up" }
        let remaining = profile.trialDaysRemaining
        if remaining <= 1 { return "Last free day — subscribe to keep your progress" }
        if remaining == 2 { return "Free access ends tomorrow — lock in your savings" }
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
                        .font(.app(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Build Financial Freedom")
                        .font(.app(size: 16, weight: .medium, design: .rounded))
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
