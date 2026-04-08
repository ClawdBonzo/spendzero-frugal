import SwiftUI

/// Full-screen celebration overlay for level-up events
struct LevelUpCelebrationView: View {
    let newLevel: Int
    let rank: LevelRank
    let previousLevel: Int
    let onDismiss: () -> Void

    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Confetti effect
                if showConfetti {
                    ConfettiView()
                        .frame(height: 300)
                }

                Spacer()

                // Level-up card
                VStack(spacing: 16) {
                    // Star animation
                    Image(systemName: "star.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundColor(AppTheme.accentGold)
                        .scaleEffect(scale)

                    // Level text
                    VStack(spacing: 8) {
                        Text("LEVEL UP!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.accentGold)

                        HStack(spacing: 12) {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Level \(previousLevel)")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                Text("Previous")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textTertiary)
                            }

                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppTheme.primaryGreen)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Level \(newLevel)")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.accentGold)
                                Text("Now")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }

                        Text(rank.title)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(AppTheme.primaryGreen)
                            .padding(.top, 8)
                    }

                    // Unlocked features
                    if !rank.unlockedFeatures.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Features Unlocked")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                                .padding(.horizontal)

                            VStack(spacing: 6) {
                                ForEach(rank.unlockedFeatures.prefix(3), id: \.self) { feature in
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(AppTheme.primaryGreen)
                                        Text(feature)
                                            .font(AppTheme.smallFont)
                                            .foregroundColor(AppTheme.textPrimary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .fill(AppTheme.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppTheme.primaryGreen.opacity(0.5),
                                    AppTheme.accentGold.opacity(0.5),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .scaleEffect(scale)
                .opacity(opacity)

                Spacer()

                // Dismiss button
                Button(action: onDismiss) {
                    Text("Awesome!")
                        .font(AppTheme.headlineFont)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.paddingMedium)
                        .background(AppTheme.primaryGreen)
                        .cornerRadius(AppTheme.cornerRadiusMedium)
                }
                .padding(.horizontal, AppTheme.paddingLarge)
                .padding(.bottom, AppTheme.paddingLarge)
            }
        }
        .onAppear {
            HapticManager.shared.trigger(.levelUp)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
                showConfetti = true
            }
        }
    }
}

// MARK: - Confetti Particle

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Image(systemName: particle.icon)
                    .font(.system(size: particle.size, weight: .semibold))
                    .foregroundColor(particle.color)
                    .offset(x: particle.offsetX, y: particle.offsetY)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            generateConfetti()
        }
    }

    private func generateConfetti() {
        for _ in 0..<20 {
            let particle = ConfettiParticle(
                x: CGFloat.random(in: -100...100),
                y: CGFloat.random(in: -50...300)
            )
            particles.append(particle)

            withAnimation(.easeInOut(duration: 2.0).delay(Double.random(in: 0...0.3))) {
                var p = particle
                p.offsetY = 400
                p.opacity = 0
                if let index = particles.firstIndex(where: { $0.id == p.id }) {
                    particles[index] = p
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let size: Double
    var offsetX: CGFloat
    var offsetY: CGFloat
    var opacity: Double = 1.0

    init(x: CGFloat, y: CGFloat) {
        self.offsetX = x
        self.offsetY = y
        let icons = ["star.fill", "sparkles", "diamond.fill", "heart.fill"]
        self.icon = icons.randomElement() ?? "star.fill"
        let colors: [Color] = [
            AppTheme.accentGold,
            AppTheme.primaryGreen,
            Color(hex: "FF6B9D"),
        ]
        self.color = colors.randomElement() ?? AppTheme.accentGold
        self.size = Double.random(in: 12...24)
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
