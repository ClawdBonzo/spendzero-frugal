import SwiftUI

struct OnboardingSplashView: View {
    let onNext: () -> Void
    @State private var showContent = false
    @State private var showButton = false
    @State private var iconScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0
    @State private var glowPulse = false
    @State private var titleOffset: CGFloat = 30
    @State private var subtitleOffset: CGFloat = 40
    @State private var descOffset: CGFloat = 50

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Animated radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.primaryGreen.opacity(0.25),
                            AppTheme.primaryGreen.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -60)
                .opacity(glowOpacity)
                .scaleEffect(glowPulse ? 1.1 : 1.0)

            VStack(spacing: 0) {
                Spacer()

                // Brand icon with animated glow ring
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(AppTheme.primaryGreen.opacity(0.1), lineWidth: 1)
                        .frame(width: 190, height: 190)
                        .scaleEffect(glowPulse ? 1.05 : 0.95)
                        .opacity(glowOpacity * 0.5)

                    // Inner glow ring
                    Circle()
                        .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .opacity(glowOpacity)

                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: AppTheme.primaryGreen.opacity(0.5), radius: 20, y: 6)
                        .scaleEffect(iconScale)
                }

                Spacer().frame(height: 32)

                // App name + tagline with staggered entry
                VStack(spacing: 12) {
                    Text("SpendZero")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .offset(y: showContent ? 0 : titleOffset)
                        .opacity(showContent ? 1 : 0)

                    Text("Start Your Wealth Journey")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.primaryGreen, AppTheme.accentGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(y: showContent ? 0 : subtitleOffset)
                        .opacity(showContent ? 1 : 0)

                    Text("Track no-spend days, crush impulse buys,\nand watch your savings grow")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .offset(y: showContent ? 0 : descOffset)
                        .opacity(showContent ? 1 : 0)
                }

                Spacer()

                if showButton {
                    PrimaryButton(title: "Begin Your Journey", icon: "arrow.right") {
                        onNext()
                    }
                    .padding(.horizontal, AppTheme.paddingLarge)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            // Icon bounce in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                iconScale = 1.0
            }
            // Glow fade in
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                glowOpacity = 1.0
            }
            // Staggered text entry
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.4)) {
                showContent = true
                titleOffset = 0
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.55)) {
                subtitleOffset = 0
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.7)) {
                descOffset = 0
            }
            // Button slide up
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.0)) {
                showButton = true
            }
            // Continuous glow pulse
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.2)) {
                glowPulse = true
            }
        }
    }
}
