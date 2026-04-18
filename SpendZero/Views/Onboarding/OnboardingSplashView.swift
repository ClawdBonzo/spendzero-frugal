import SwiftUI

struct OnboardingSplashView: View {
    let onNext: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Entrance animation state
    @State private var showContent = false
    @State private var showButton = false
    @State private var iconScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var subtitleOffset: CGFloat = 40
    @State private var descOffset: CGFloat = 50

    // Continuous animation state
    @State private var glowPulse = false
    @State private var iconFloat = false
    @State private var iconWobble = false
    @State private var ringExpand1 = false
    @State private var ringExpand2 = false
    @State private var ringExpand3 = false
    @State private var taglineShimmer: Double = -1.0
    @State private var buttonGlow = false
    @State private var sparkleRotate: Double = 0

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Money/sparkle particles in background
            ParticleBackgroundView(count: 12)
                .ignoresSafeArea()
                .opacity(0.7)

            // Animated radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.primaryGreen.opacity(0.30),
                            AppTheme.primaryGreen.opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 220
                    )
                )
                .frame(width: 450, height: 450)
                .offset(y: -60)
                .opacity(glowOpacity)
                .scaleEffect(glowPulse ? 1.15 : 0.95)

            VStack(spacing: 0) {
                Spacer()

                // Brand icon with multiple expanding rings
                ZStack {
                    // Three expanding ripple rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(AppTheme.primaryGreen.opacity(0.4), lineWidth: 2)
                            .frame(width: 130, height: 130)
                            .scaleEffect(rippleScale(for: i))
                            .opacity(rippleOpacity(for: i))
                    }

                    // Static glow rings behind icon
                    Circle()
                        .stroke(AppTheme.primaryGreen.opacity(0.15), lineWidth: 1)
                        .frame(width: 200, height: 200)
                        .scaleEffect(glowPulse ? 1.08 : 0.96)
                        .opacity(glowOpacity * 0.7)

                    Circle()
                        .stroke(AppTheme.primaryGreen.opacity(0.25), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .opacity(glowOpacity)

                    // Floating sparkles around icon
                    ForEach(0..<6, id: \.self) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.accentGold.opacity(0.7))
                            .offset(sparkleOffset(for: i))
                            .opacity(showContent ? 0.8 : 0)
                            .rotationEffect(.degrees(sparkleRotate))
                    }

                    // Brand icon — floats up/down, slight wobble
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: AppTheme.primaryGreen.opacity(0.6), radius: 24, y: 8)
                        .scaleEffect(iconScale)
                        .offset(y: iconFloat ? -8 : 8)
                        .rotationEffect(.degrees(iconWobble ? 2 : -2))
                }

                Spacer().frame(height: 40)

                // App name + tagline
                VStack(spacing: 14) {
                    Text("SpendZero")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .shadow(color: AppTheme.primaryGreen.opacity(0.3), radius: 10)
                        .offset(y: showContent ? 0 : titleOffset)
                        .opacity(showContent ? 1 : 0)

                    // Shimmering gradient tagline
                    Text("Start Your Wealth Journey")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: AppTheme.primaryGreen, location: 0),
                                    .init(color: AppTheme.accentGold, location: 0.5),
                                    .init(color: AppTheme.primaryGreen, location: 1)
                                ],
                                startPoint: UnitPoint(x: taglineShimmer, y: 0.5),
                                endPoint: UnitPoint(x: taglineShimmer + 1, y: 0.5)
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
                    .shadow(color: AppTheme.primaryGreen.opacity(buttonGlow ? 0.7 : 0.3), radius: buttonGlow ? 20 : 8, y: 4)
                    .scaleEffect(buttonGlow ? 1.02 : 1.0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer().frame(height: 40)
            }
        }
        .onAppear { startAllAnimations() }
    }

    // MARK: - Computed sparkle positions

    private func sparkleOffset(for index: Int) -> CGSize {
        let angle = (Double(index) / 6.0) * Double.pi * 2 + (sparkleRotate * Double.pi / 180.0)
        let radius: CGFloat = 95
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }

    private func rippleScale(for index: Int) -> CGFloat {
        let baseScales: [CGFloat] = [
            ringExpand1 ? 1.6 : 1.0,
            ringExpand2 ? 1.6 : 1.0,
            ringExpand3 ? 1.6 : 1.0
        ]
        return baseScales[index]
    }

    private func rippleOpacity(for index: Int) -> Double {
        let baseOpacities: [Double] = [
            ringExpand1 ? 0 : 0.6,
            ringExpand2 ? 0 : 0.6,
            ringExpand3 ? 0 : 0.6
        ]
        return baseOpacities[index] * glowOpacity
    }

    // MARK: - Animation orchestration

    private func startAllAnimations() {
        // Initial entrance — icon bounce
        withAnimation(.spring(response: 0.8, dampingFraction: 0.55)) {
            iconScale = 1.0
        }

        // Glow fade in
        withAnimation(.easeOut(duration: 0.9).delay(0.3)) {
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

        // ===== Continuous loops =====
        guard !reduceMotion else { return }

        // Glow pulse
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.2)) {
            glowPulse = true
        }

        // Icon float (vertical bob)
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(1.0)) {
            iconFloat = true
        }

        // Icon wobble (subtle rotation)
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true).delay(1.0)) {
            iconWobble = true
        }

        // Sparkles rotate slowly around icon
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false).delay(1.5)) {
            sparkleRotate = 360
        }

        // Three staggered ripples (looped continuously)
        startRippleLoop(ring: 0, delay: 1.5)
        startRippleLoop(ring: 1, delay: 2.4)
        startRippleLoop(ring: 2, delay: 3.3)

        // Tagline shimmer sweep
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false).delay(1.5)) {
            taglineShimmer = 1.0
        }

        // Button glow breathe
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.5)) {
            buttonGlow = true
        }
    }

    private func startRippleLoop(ring: Int, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 2.7).repeatForever(autoreverses: false)) {
                switch ring {
                case 0: ringExpand1 = true
                case 1: ringExpand2 = true
                default: ringExpand3 = true
                }
            }
        }
    }
}
