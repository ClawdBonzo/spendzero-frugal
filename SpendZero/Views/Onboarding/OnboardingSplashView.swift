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

                // Brand icon + onboarding illustration
                VStack(spacing: 16) {
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: AppTheme.primaryGreen.opacity(0.4), radius: 16, y: 6)
                        .scaleEffect(iconScale)

                    Image("Onboarding-1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .opacity(showContent ? 1 : 0)
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
