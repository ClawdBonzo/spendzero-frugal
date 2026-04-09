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
                .offset(y: -60)
                .opacity(glowOpacity)

            VStack(spacing: 0) {
                Spacer()

                // Brand icon with glow ring
                ZStack {
                    Circle()
                        .stroke(AppTheme.primaryGreen.opacity(0.15), lineWidth: 2)
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

                // App name + tagline
                VStack(spacing: 12) {
                    Text("SpendZero")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Start Your Wealth Journey")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(showContent ? 1 : 0)

                    Text("Track no-spend days, crush impulse buys,\nand watch your savings grow")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
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
