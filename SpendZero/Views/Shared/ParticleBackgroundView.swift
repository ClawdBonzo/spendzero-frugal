import SwiftUI

// MARK: - ParticleBackgroundView
// Money/growth-themed animated particle background.
// • Uses TimelineView + Canvas for GPU-composited rendering (no per-particle State)
// • Respects accessibilityReduceMotion — renders nothing when enabled
// • drawingGroup() flattens to a single CALayer for 60 fps on all supported devices
// • Particle count capped at 12; lifetime is long (10–20 s) for gentle movement

struct ParticleBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particles: [BgParticle]
    private let startDate = Date.now

    init(count: Int = 10) {
        // Generate deterministic particles at init time — no re-renders from State
        var rng = SystemRandomNumberGenerator()
        particles = (0..<min(count, 12)).map { _ in BgParticle(rng: &rng) }
    }

    var body: some View {
        Group {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { ctx, size in
                        guard size.width > 0, size.height > 0 else { return }
                        let elapsed = timeline.date.timeIntervalSince(startDate)
                        for p in particles {
                            drawParticle(p, in: &ctx, size: size, elapsed: elapsed)
                        }
                    }
                    .drawingGroup()
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawParticle(_ p: BgParticle, in ctx: inout GraphicsContext, size: CGSize, elapsed: Double) {
        // Normalised lifecycle 0→1, loops continuously
        let raw = elapsed + p.timeOffset
        let cycle = raw.truncatingRemainder(dividingBy: p.lifetime) / p.lifetime

        // Float from bottom to top
        let y = size.height * 1.05 - size.height * 1.15 * cycle
        let x = p.xFraction * size.width + sin(elapsed * p.wobble + p.phase) * 22

        // Smooth fade in (first 10%) and out (last 15%)
        let alpha = cycle < 0.10 ? cycle / 0.10
                  : cycle > 0.85 ? (1.0 - cycle) / 0.15
                  : 1.0

        var inner = ctx
        inner.opacity = p.opacity * min(alpha, 1.0)
        inner.draw(
            Text(p.symbol).font(.system(size: p.size)),
            at: CGPoint(x: x, y: y)
        )
    }
}

// MARK: - Particle Model

struct BgParticle {
    let symbol: String
    let size: CGFloat
    let xFraction: Double   // normalised 0…1 across screen width
    let timeOffset: Double  // lifecycle stagger (seconds)
    let lifetime: Double    // seconds per full rise
    let wobble: Double      // horizontal wobble frequency
    let phase: Double       // wobble phase offset
    let opacity: Double     // max alpha (kept low for subtlety)

    private static let symbols = ["💰", "✨", "🌿", "💎", "📈", "🍃", "⭐️", "🌱", "💵", "🪙"]

    init(rng: inout SystemRandomNumberGenerator) {
        symbol    = Self.symbols.randomElement(using: &rng)!
        size      = CGFloat.random(in: 10...18, using: &rng)
        xFraction = Double.random(in: 0.05...0.95, using: &rng)
        timeOffset = Double.random(in: 0...20, using: &rng)
        lifetime  = Double.random(in: 10...22, using: &rng)
        wobble    = Double.random(in: 0.20...0.55, using: &rng)
        phase     = Double.random(in: 0...(Double.pi * 2), using: &rng)
        opacity   = Double.random(in: 0.20...0.45, using: &rng)
    }
}
