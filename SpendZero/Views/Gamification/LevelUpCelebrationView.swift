import SwiftUI

/// Full-screen celebration overlay for level-up events
struct LevelUpCelebrationView: View {
    let newLevel: Int
    let rank: LevelRank
    let previousLevel: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0
    @State private var starPulse = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Confetti layer (behind card)
            if showConfetti && !reduceMotion {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer()

                // Level-up card
                VStack(spacing: 20) {
                    // Animated star / crown
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentGold.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .scaleEffect(starPulse ? 1.15 : 0.9)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.accentGold, Color(hex: "FF8C00")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                        value: starPulse
                    )

                    // LEVEL UP text
                    Text("LEVEL UP!")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.accentGold, AppTheme.primaryGreen],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )

                    // Before → After
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text("Level \(previousLevel)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("Before")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.primaryGreen)

                        VStack(spacing: 4) {
                            Text("Level \(newLevel)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.accentGold)
                            Text("Now")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Rank title
                    Text(rank.title)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen)

                    // Unlocked features
                    if !rank.unlockedFeatures.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("New Unlocks")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textTertiary)

                            ForEach(rank.unlockedFeatures.prefix(3), id: \.self) { feature in
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.primaryGreen)
                                    Text(LocalizedStringKey(feature))
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppTheme.primaryGreen.opacity(0.5), AppTheme.accentGold.opacity(0.5)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                )
                .shadow(color: AppTheme.primaryGreen.opacity(0.2), radius: 20, y: 8)
                .padding(.horizontal, 24)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                        Text("Awesome!")
                    }
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            HapticManager.shared.trigger(.levelUp)
            withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    starPulse = true
                }
                // Slight delay so card appears first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfetti = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Level up! You reached Level \(newLevel): \(rank.title)")
    }
}

// MARK: - ConfettiView (fixed)
// Previously broken: used value-type struct mutation inside withAnimation block.
// Now: computes start/end positions up front; single `animated` bool drives all transitions.

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animated = false

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: p.icon)
                    .font(.system(size: p.size, weight: .semibold))
                    .foregroundColor(p.color)
                    .offset(
                        x: p.startX + (animated ? p.driftX : 0),
                        y: animated ? p.endY : p.startY
                    )
                    .opacity(animated ? 0 : p.opacity)
                    .rotationEffect(.degrees(animated ? p.finalRotation : 0))
                    .animation(
                        .easeOut(duration: p.duration).delay(p.delay),
                        value: animated
                    )
            }
        }
        .onAppear {
            particles = (0..<28).map { _ in ConfettiParticle() }
            // Tiny delay lets the view appear before animation fires
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animated = true
            }
        }
    }
}

// MARK: - ConfettiParticle

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let size: Double
    // Start
    let startX: CGFloat
    let startY: CGFloat
    // End deltas (applied when animated == true)
    let driftX: CGFloat
    let endY: CGFloat
    // Rotation
    let finalRotation: Double
    // Animation timing
    let duration: Double
    let delay: Double
    let opacity: Double

    private static let icons  = ["star.fill", "sparkles", "dollarsign.circle.fill", "heart.fill", "crown.fill", "diamond.fill"]
    private static let colors: [Color] = [AppTheme.accentGold, AppTheme.primaryGreen, Color(hex: "FF6B9D"), Color(hex: "60CFFF"), .white]

    init() {
        startX = CGFloat.random(in: -180...180)
        startY = CGFloat.random(in: -100...100)
        driftX = CGFloat.random(in: -60...60)
        endY   = startY + CGFloat.random(in: 350...600)
        finalRotation = Double.random(in: -360...360)
        icon     = Self.icons.randomElement()!
        color    = Self.colors.randomElement()!
        size     = Double.random(in: 14...28)
        duration = Double.random(in: 1.8...2.8)
        delay    = Double.random(in: 0...0.6)
        opacity  = Double.random(in: 0.6...1.0)
    }
}

#Preview {
    LevelUpCelebrationView(
        newLevel: 12,
        rank: .fortuneWeaver,
        previousLevel: 11,
        onDismiss: {}
    )
}
