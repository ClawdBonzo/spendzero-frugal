import SwiftUI

/// Visual money tree that grows through level progression.
/// Uses Canvas with GeometryReader for adaptive sizing, particle overlay,
/// and accessibilityReduceMotion support.
struct MoneyTreeView: View {
    let gameProfile: GameProfile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateGrowth = false
    @State private var bgParticles: [Particle] = []

    var treeStage: Int {
        switch gameProfile.currentLevel {
        case ...5:  return 1   // Seedling
        case ...10: return 2   // Sprout
        case ...15: return 3   // Young Tree
        case ...20: return 4   // Tall Tree
        default:    return 5   // Full Palm
        }
    }

    var stageIcon: String {
        switch treeStage {
        case 1: return "leaf.fill"
        case 2: return "leaf.circle.fill"
        case 3: return "tree.fill"
        case 4: return "tree.fill"
        default: return "crown.fill"
        }
    }

    var stageTitle: String {
        switch treeStage {
        case 1: return "Seedling"
        case 2: return "Sprout"
        case 3: return "Young Tree"
        case 4: return "Tall Tree"
        default: return "Full Palm"
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("Your Wealth Tree")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Growing with your financial wisdom")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Tree canvas — uses GeometryReader so coordinates scale to container
            GeometryReader { geo in
                ZStack {
                    // Base canvas
                    Canvas { context, size in
                        let anchor = CGPoint(x: size.width / 2, y: size.height * 0.90)
                        drawTree(on: &context, at: anchor, stage: treeStage, canvasSize: size)
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: treeStage)

                    // Floating coin particles (hidden when reduceMotion)
                    if !reduceMotion {
                        ForEach(bgParticles, id: \.id) { particle in
                            ParticleView(particle: particle)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
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
            .accessibilityLabel("Wealth tree at stage \(treeStage): \(stageTitle)")
            .accessibilityValue("Level \(gameProfile.currentLevel)")

            // Stage info
            VStack(spacing: 8) {
                HStack {
                    Text("Current Stage")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: stageIcon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(stageTitle)
                            .font(AppTheme.headlineFont)
                    }
                    .foregroundColor(AppTheme.accentGold)
                }

                if treeStage < 5 {
                    let nextStageLevel = treeStage * 5 + 1
                    VStack(spacing: 6) {
                        HStack {
                            Text("Level \(nextStageLevel) for next stage")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                            Spacer()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.cardBackgroundLight)
                                    .frame(height: 8)
                                let progress = min(1.0, Double(gameProfile.currentLevel) / Double(nextStageLevel))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [AppTheme.primaryGreen, AppTheme.accentGold],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * progress, height: 8)
                                    .animation(reduceMotion ? nil : .spring(response: 0.6), value: gameProfile.currentLevel)
                            }
                        }
                        .frame(height: 8)
                    }
                } else {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(AppTheme.accentGold)
                        Text("Wealth King — Ultimate status achieved!")
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
            if !reduceMotion { generateParticles() }
        }
        .onChange(of: treeStage) { _, _ in
            if !reduceMotion { generateParticles() }
        }
    }

    // MARK: - Drawing

    private func drawTree(on context: inout GraphicsContext, at anchor: CGPoint, stage: Int, canvasSize: CGSize) {
        // Scale factor so tree fills the canvas proportionally
        let scale = min(canvasSize.width, canvasSize.height) / 250.0

        switch stage {
        case 1: drawSeedling(on: &context, at: anchor, scale: scale)
        case 2: drawSprout(on:   &context, at: anchor, scale: scale)
        case 3: drawYoungTree(on: &context, at: anchor, scale: scale)
        case 4: drawTallTree(on: &context, at: anchor, scale: scale)
        default: drawFullPalm(on: &context, at: anchor, scale: scale)
        }
    }

    private func drawSeedling(on ctx: inout GraphicsContext, at p: CGPoint, scale: CGFloat) {
        var stem = Path()
        stem.move(to: p)
        stem.addLine(to: CGPoint(x: p.x, y: p.y - 30 * scale))
        ctx.stroke(stem, with: .color(AppTheme.primaryGreen), lineWidth: 2 * scale)

        let leaf = Circle().path(in: CGRect(x: p.x - 9 * scale, y: p.y - 48 * scale, width: 18 * scale, height: 18 * scale))
        ctx.fill(leaf, with: .color(AppTheme.primaryGreen))
    }

    private func drawSprout(on ctx: inout GraphicsContext, at p: CGPoint, scale: CGFloat) {
        var trunk = Path()
        trunk.move(to: p)
        trunk.addLine(to: CGPoint(x: p.x, y: p.y - 40 * scale))
        ctx.stroke(trunk, with: .color(Color(hex: "8B6914")), lineWidth: 3 * scale)

        let crown = Circle().path(in: CGRect(x: p.x - 18 * scale, y: p.y - 65 * scale, width: 36 * scale, height: 36 * scale))
        ctx.fill(crown, with: .color(AppTheme.primaryGreen))
    }

    private func drawYoungTree(on ctx: inout GraphicsContext, at p: CGPoint, scale: CGFloat) {
        var trunk = Path()
        trunk.move(to: p)
        trunk.addLine(to: CGPoint(x: p.x, y: p.y - 55 * scale))
        ctx.stroke(trunk, with: .color(Color(hex: "704020")), lineWidth: 5 * scale)

        let crown = Circle().path(in: CGRect(x: p.x - 30 * scale, y: p.y - 95 * scale, width: 60 * scale, height: 60 * scale))
        ctx.fill(crown, with: .color(AppTheme.primaryGreen))
        let inner = Circle().path(in: CGRect(x: p.x - 20 * scale, y: p.y - 80 * scale, width: 40 * scale, height: 40 * scale))
        ctx.fill(inner, with: .color(Color(hex: "00D65C")))
    }

    private func drawTallTree(on ctx: inout GraphicsContext, at p: CGPoint, scale: CGFloat) {
        var trunk = Path()
        trunk.move(to: p)
        trunk.addLine(to: CGPoint(x: p.x, y: p.y - 70 * scale))
        ctx.stroke(trunk, with: .color(Color(hex: "5C3D2E")), lineWidth: 6 * scale)

        let crown = Circle().path(in: CGRect(x: p.x - 42 * scale, y: p.y - 120 * scale, width: 84 * scale, height: 84 * scale))
        ctx.fill(crown, with: .color(AppTheme.primaryGreen))
        let inner = Circle().path(in: CGRect(x: p.x - 28 * scale, y: p.y - 100 * scale, width: 56 * scale, height: 56 * scale))
        ctx.fill(inner, with: .color(Color(hex: "00D65C")))
    }

    private func drawFullPalm(on ctx: inout GraphicsContext, at p: CGPoint, scale: CGFloat) {
        var trunk = Path()
        trunk.move(to: p)
        trunk.addLine(to: CGPoint(x: p.x, y: p.y - 80 * scale))
        ctx.stroke(trunk, with: .color(Color(hex: "4A2E22")), lineWidth: 7 * scale)

        let crown = Circle().path(in: CGRect(x: p.x - 52 * scale, y: p.y - 145 * scale, width: 104 * scale, height: 104 * scale))
        ctx.fill(crown, with: .color(AppTheme.primaryGreen))
        let inner = Circle().path(in: CGRect(x: p.x - 34 * scale, y: p.y - 120 * scale, width: 68 * scale, height: 68 * scale))
        ctx.fill(inner, with: .color(Color(hex: "00E676")))

        // Gold fruits arranged in a ring
        for angle in stride(from: 0, to: CGFloat.pi * 2, by: CGFloat.pi / 6) {
            let radius = 48 * scale
            let fx = p.x + radius * cos(angle)
            let fy = p.y - 90 * scale + radius * sin(angle)
            let fruit = Circle().path(in: CGRect(x: fx - 5 * scale, y: fy - 5 * scale, width: 10 * scale, height: 10 * scale))
            ctx.fill(fruit, with: .color(AppTheme.accentGold))
        }
    }

    // MARK: - Particles

    private func generateParticles() {
        bgParticles = (0..<6).map { _ in
            Particle(
                id: UUID(),
                startPosition: CGPoint(
                    x: CGFloat.random(in: 30...270),
                    y: CGFloat.random(in: 120...190)
                ),
                duration: Double.random(in: 2...4),
                delay: Double.random(in: 0...1)
            )
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
        CGPoint(
            x: startPosition.x + CGFloat.random(in: -25...25),
            y: startPosition.y - CGFloat.random(in: 60...120)
        )
    }
}

struct ParticleView: View {
    let particle: Particle
    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0

    var body: some View {
        Image(systemName: "dollarsign.circle.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(AppTheme.accentGold)
            .shadow(color: AppTheme.accentGold.opacity(0.5), radius: 3)
            .position(position)
            .opacity(opacity)
            .onAppear {
                position = particle.startPosition
                opacity = 0.8
                withAnimation(.easeOut(duration: particle.duration).delay(particle.delay)) {
                    position = particle.endPosition
                    opacity = 0
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
