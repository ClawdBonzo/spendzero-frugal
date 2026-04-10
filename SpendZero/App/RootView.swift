import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenPaywall") private var hasSeenPaywall = false
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingFlowView()
                } else if !hasSeenPaywall {
                    PaywallView(onContinue: {
                        hasSeenPaywall = true
                    })
                } else {
                    MainTabView()
                }
            }
            .animation(.easeInOut(duration: 0.4), value: hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.4), value: hasSeenPaywall)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Ensure existing users have a GameProfile (fixes crash for users who
            // completed onboarding before GameProfile creation was added)
            if let profile = profiles.first, profile.gameProfile == nil {
                let gp = GameProfile()
                modelContext.insert(gp)
                profile.gameProfile = gp
                try? modelContext.save()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
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
