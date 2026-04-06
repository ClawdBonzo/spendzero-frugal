import SwiftUI

struct OnboardingSplashView: View {
    let onNext: () -> Void
    @State private var showContent = false
    @State private var showButton = false
    @State private var iconScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.primaryGreen.opacity(0.2),
                            AppTheme.primaryGreen.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .opacity(glowOpacity)

            VStack(spacing: 40) {
                Spacer()

                // Logo / Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.primaryGreen.opacity(0.1))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(AppTheme.primaryGreen.opacity(0.15))
                        .frame(width: 110, height: 110)

                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppTheme.primaryGradient)
                        .scaleEffect(iconScale)
                }

                VStack(spacing: 16) {
                    Text("SpendZero")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Start Your Wealth Journey")
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.primaryGreen)
                        .opacity(showContent ? 1 : 0)

                    Text("Track no-spend days, crush impulse buys,\nand watch your savings grow")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                }

                Spacer()

                if showButton {
                    PrimaryButton(title: "Begin Your Journey", icon: "arrow.right") {
                        onNext()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AppTheme.paddingLarge)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                glowOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.0)) {
                showButton = true
            }
        }
    }
}
