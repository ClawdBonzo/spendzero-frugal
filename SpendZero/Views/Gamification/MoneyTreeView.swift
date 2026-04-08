import SwiftUI

/// Visual money tree that grows through level progression with Canvas-based drawing and particle effects
struct MoneyTreeView: View {
    let gameProfile: GameProfile

    @State private var animateGrowth = false
    @State private var particles: [Particle] = []

    var treeStage: Int {
        let level = gameProfile.currentLevel
        if level <= 5 { return 1 }      // Seedling
        if level <= 10 { return 2 }     // Sprout
        if level <= 15 { return 3 }     // Young Tree
        if level <= 20 { return 4 }     // Tall Tree
        return 5                          // Full Palm
    }

    var stageTitle: String {
        switch treeStage {
        case 1: return "🌱 Seedling"
        case 2: return "🌿 Sprout"
        case 3: return "🌳 Young Tree"
        case 4: return "🌲 Tall Tree"
        case 5: return "🌴 Full Palm"
        default: return "🌳 Tree"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Title
            VStack(spacing: 4) {
                Text("Your Wealth Tree")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Growing with your financial wisdom")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Tree Canvas
            Canvas { context in
                drawTree(on: &context, at: CGPoint(x: 150, y: 100), stage: treeStage)
            }
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 1)
            )

            // Particle Effects Overlay
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    ParticleView(particle: particle)
                }
            }
            .frame(height: 200)
            .offset(y: -200)

            // Stage Info
            VStack(spacing: 8) {
                HStack {
                    Text("Current Stage")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text(stageTitle)
                        .font(AppTheme.headlineFont)
                        .foregroundColor(AppTheme.accentGold)
                }

                // Progress to next stage
                if treeStage < 5 {
                    let nextStageLevel = treeStage * 5
                    VStack(spacing: 6) {
                        HStack {
                            Text("Level \(nextStageLevel) for next stage")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                            Spacer()
                        }

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppTheme.cardBackgroundLight)

                            let progress = Double(gameProfile.currentLevel) / Double(nextStageLevel)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppTheme.primaryGreen, AppTheme.accentGold]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 280 * min(1, progress), height: 8)
                        }
                        .frame(height: 8)
                    }
                } else {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppTheme.accentGold)
                        Text("You've reached the ultimate Wealth King status!")
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.accentGold)
                    }
                }
            }
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
        .padding(AppTheme.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.background)
        )
        .onAppear {
            animateGrowth = true
            generateParticles()
        }
        .onChange(of: treeStage) { _ in
            generateParticles()
        }
    }

    private func drawTree(on context: inout GraphicsContext, at position: CGPoint, stage: Int) {
        switch stage {
        case 1:
            drawSeedling(on: &context, at: position)
        case 2:
            drawSprout(on: &context, at: position)
        case 3:
            drawYoungTree(on: &context, at: position)
        case 4:
            drawTallTree(on: &context, at: position)
        case 5:
            drawFullPalm(on: &context, at: position)
        default:
            drawSeedling(on: &context, at: position)
        }
    }

    private func drawSeedling(on context: inout GraphicsContext, at position: CGPoint) {
        // Simple seedling: small green circle on stem
        var path = Path()
        path.move(to: position)
        path.addLine(to: CGPoint(x: position.x, y: position.y - 20))

        context.stroke(
            path,
            with: .color(AppTheme.primaryGreen),
            lineWidth: 2
        )

        // Leaf circle
        let leafPath = Circle()
            .path(in: CGRect(x: position.x - 8, y: position.y - 35, width: 16, height: 16))
        context.fill(leafPath, with: .color(AppTheme.primaryGreen))
    }

    private func drawSprout(on context: inout GraphicsContext, at position: CGPoint) {
        // Trunk
        var trunkPath = Path()
        trunkPath.move(to: position)
        trunkPath.addLine(to: CGPoint(x: position.x, y: position.y - 30))

        context.stroke(
            trunkPath,
            with: .color(Color(hex: "8B6914")),  // Brown
            lineWidth: 3
        )

        // Small crown
        let crownPath = Circle()
            .path(in: CGRect(x: position.x - 15, y: position.y - 50, width: 30, height: 30))
        context.fill(crownPath, with: .color(AppTheme.primaryGreen))
    }

    private func drawYoungTree(on context: inout GraphicsContext, at position: CGPoint) {
        // Trunk
        var trunkPath = Path()
        trunkPath.move(to: position)
        trunkPath.addLine(to: CGPoint(x: position.x, y: position.y - 40))

        context.stroke(
            trunkPath,
            with: .color(Color(hex: "704020")),  // Darker brown
            lineWidth: 4
        )

        // Medium crown
        let crownPath = Circle()
            .path(in: CGRect(x: position.x - 25, y: position.y - 70, width: 50, height: 50))
        context.fill(crownPath, with: .color(AppTheme.primaryGreen))
    }

    private func drawTallTree(on context: inout GraphicsContext, at position: CGPoint) {
        // Trunk with taper
        var trunkPath = Path()
        trunkPath.move(to: position)
        trunkPath.addLine(to: CGPoint(x: position.x, y: position.y - 50))

        context.stroke(
            trunkPath,
            with: .color(Color(hex: "5C3D2E")),  // Very dark brown
            lineWidth: 5
        )

        // Larger crown
        let crownPath = Circle()
            .path(in: CGRect(x: position.x - 35, y: position.y - 95, width: 70, height: 70))
        context.fill(crownPath, with: .color(AppTheme.primaryGreen))

        // Add some depth with second layer
        let innerCrown = Circle()
            .path(in: CGRect(x: position.x - 25, y: position.y - 80, width: 50, height: 50))
        context.fill(innerCrown, with: .color(Color(hex: "00D65C")))  // Lighter green
    }

    private func drawFullPalm(on context: inout GraphicsContext, at position: CGPoint) {
        // Large trunk
        var trunkPath = Path()
        trunkPath.move(to: position)
        trunkPath.addLine(to: CGPoint(x: position.x, y: position.y - 60))

        context.stroke(
            trunkPath,
            with: .color(Color(hex: "4A2E22")),  // Very dark brown
            lineWidth: 6
        )

        // Large crown
        let crownPath = Circle()
            .path(in: CGRect(x: position.x - 45, y: position.y - 110, width: 90, height: 90))
        context.fill(crownPath, with: .color(AppTheme.primaryGreen))

        // Inner lighter green for depth
        let innerCrown = Circle()
            .path(in: CGRect(x: position.x - 30, y: position.y - 90, width: 60, height: 60))
        context.fill(innerCrown, with: .color(Color(hex: "00E676")))  // Bright green

        // Gold accents (fruits)
        for angle in stride(from: 0, to: CGFloat.pi * 2, by: CGFloat.pi / 6) {
            let x = position.x - 40 * cos(angle)
            let y = position.y - 70 - 40 * sin(angle)
            let fruitPath = Circle()
                .path(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
            context.fill(fruitPath, with: .color(AppTheme.accentGold))
        }
    }

    private func generateParticles() {
        // Generate floating coin particles
        particles.removeAll()
        for _ in 0..<5 {
            let startX = CGFloat.random(in: 50...250)
            let startY = CGFloat.random(in: 100...200)
            let duration = Double.random(in: 2...4)
            let delay = Double.random(in: 0...0.5)

            particles.append(Particle(
                id: UUID(),
                startPosition: CGPoint(x: startX, y: startY),
                duration: duration,
                delay: delay
            ))
        }
    }
}

// MARK: - Particle Model and View

struct Particle: Identifiable {
    let id: UUID
    let startPosition: CGPoint
    let duration: Double
    let delay: Double

    var endPosition: CGPoint {
        CGPoint(x: startPosition.x + CGFloat.random(in: -30...30), y: startPosition.y - 100)
    }
}

struct ParticleView: View {
    let particle: Particle

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "coin.fill")
            .font(.system(size: 12))
            .foregroundColor(AppTheme.accentGold)
            .position(position)
            .opacity(opacity)
            .onAppear {
                position = particle.startPosition
                withAnimation(.easeInOut(duration: particle.duration).delay(particle.delay)) {
                    position = particle.endPosition
                    opacity = 0.0
                }
            }
    }
}

#Preview {
    let profile = GameProfile()
    profile.currentLevel = 15

    return MoneyTreeView(gameProfile: profile)
        .background(AppTheme.background)
}
