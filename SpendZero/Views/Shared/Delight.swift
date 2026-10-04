import SwiftUI
import UIKit

// Decorative celebration pieces. All are hidden from VoiceOver, stop with Reduce Motion, and only
// run a timeline while they are visibly animating.

// MARK: - Deterministic randomness

/// SplitMix64: the same seed always produces the same sequence, so a user's tree, a stamp, or a
/// burst looks identical across launches, previews and screenshots.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Cash confetti

struct CashConfettiParticle {
    enum Shape: CaseIterable { case bill, coin, strip, sparkle }
    var shape: Shape
    var colorIndex: Int
    var velocity: CGVector
    var spin: Double
    var flip: Double
    var size: CGFloat
    var delay: Double
}

enum CashConfetti {
    static let gravity: Double = 640
    static let drag: Double = 1.9
    static let palette: [Color] = [
        AppTheme.primaryGreen, AppTheme.accentGold, .white,
        Color(hex: "69F0AE"), Color(hex: "FFB300"), Color(hex: "00BFA5"),
    ]

    static func particles(count: Int, seed: UInt64) -> [CashConfettiParticle] {
        var rng = SeededGenerator(seed: seed)
        let shapes = CashConfettiParticle.Shape.allCases
        return (0..<count).map { i in
            let angle = Double.random(in: (-.pi * 0.94)...(-.pi * 0.06), using: &rng)
            let speed = Double.random(in: 380...960, using: &rng)
            // Bills and coins are the signature; weight them up.
            let roll = Int.random(in: 0..<10, using: &rng)
            let shape: CashConfettiParticle.Shape = roll < 3 ? .bill : roll < 5 ? .coin : shapes[roll % 2 == 0 ? 2 : 3]
            return CashConfettiParticle(
                shape: shape,
                colorIndex: i % palette.count,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                spin: Double.random(in: -8...8, using: &rng),
                flip: Double.random(in: 4...11, using: &rng),
                size: CGFloat(Double.random(in: 7...13, using: &rng)),
                delay: Double.random(in: 0...0.12, using: &rng)
            )
        }
    }

    static func offset(of p: CashConfettiParticle, at time: Double) -> CGPoint {
        let t = max(0, time)
        let carried = (1 - exp(-drag * t)) / drag
        return CGPoint(x: p.velocity.dx * carried,
                       y: p.velocity.dy * carried + 0.5 * gravity * t * t * 0.55)
    }

    static func opacity(at time: Double, duration: Double) -> Double {
        guard duration > 0, time >= 0 else { return 0 }
        let fadeStart = duration * 0.65
        if time <= fadeStart { return 1 }
        return max(0, 1 - (time - fadeStart) / (duration - fadeStart))
    }
}

/// A one-shot burst of bills, coins and sparkles with drag, gravity and a paper-flip flutter.
/// Changing `trigger` throws another burst.
struct CashConfettiBurst: View {
    var trigger: Int
    var origin: UnitPoint = UnitPoint(x: 0.5, y: 0.42)
    var count: Int = 110
    var duration: Double = 2.8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burst: Burst?

    private struct Burst: Equatable {
        static func == (a: Burst, b: Burst) -> Bool { a.started == b.started }
        let started: Date
        let particles: [CashConfettiParticle]
    }

    var body: some View {
        ZStack {
            if let burst, !reduceMotion {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(burst.started)
                    Canvas { context, size in
                        draw(burst.particles, elapsed: elapsed, in: &context, size: size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { if trigger > 0 { fire() } }
        .onChange(of: trigger) { _, _ in fire() }
    }

    private func fire() {
        guard !reduceMotion else { return }
        let started = Date.now
        burst = Burst(started: started,
                      particles: CashConfetti.particles(count: count, seed: UInt64(truncatingIfNeeded: trigger &* 7919 &+ 17)))
        let lifetime = duration + 0.2
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(lifetime))
            if burst?.started == started { burst = nil }
        }
    }

    private func draw(_ particles: [CashConfettiParticle], elapsed: Double, in context: inout GraphicsContext, size: CGSize) {
        let start = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        let colors = CashConfetti.palette
        for p in particles {
            let t = elapsed - p.delay
            guard t > 0 else { continue }
            let alpha = CashConfetti.opacity(at: t, duration: duration - p.delay)
            guard alpha > 0 else { continue }
            let o = CashConfetti.offset(of: p, at: t)
            var layer = context
            layer.opacity = alpha
            layer.translateBy(x: start.x + o.x, y: start.y + o.y)
            layer.rotate(by: .radians(p.spin * t))
            layer.scaleBy(x: max(0.15, abs(cos(p.flip * t))), y: 1)
            let s = p.size
            switch p.shape {
            case .bill:
                let r = CGRect(x: -s, y: -s * 0.5, width: s * 2, height: s)
                layer.fill(Path(roundedRect: r, cornerRadius: 1.5), with: .color(Color(hex: "2E7D32")))
                layer.stroke(Path(roundedRect: r.insetBy(dx: 1.2, dy: 1.2), cornerRadius: 1),
                             with: .color(Color(hex: "A5D6A7").opacity(0.9)), lineWidth: 0.8)
                layer.fill(Path(ellipseIn: CGRect(x: -s * 0.28, y: -s * 0.28, width: s * 0.56, height: s * 0.56)),
                           with: .color(Color(hex: "C8E6C9")))
            case .coin:
                let r = CGRect(x: -s * 0.55, y: -s * 0.55, width: s * 1.1, height: s * 1.1)
                layer.fill(Path(ellipseIn: r), with: .color(Color(hex: "FFC400")))
                layer.stroke(Path(ellipseIn: r.insetBy(dx: s * 0.14, dy: s * 0.14)),
                             with: .color(Color(hex: "FFF3B0")), lineWidth: 1)
            case .strip:
                layer.fill(Path(roundedRect: CGRect(x: -s / 2, y: -s * 0.3, width: s, height: s * 0.6), cornerRadius: 1.5),
                           with: .color(colors[p.colorIndex % colors.count]))
            case .sparkle:
                layer.fill(Sparkle.path(size: s * 1.25), with: .color(colors[p.colorIndex % colors.count]))
            }
        }
    }
}

enum Sparkle {
    /// A four-pointed sparkle centred on the origin.
    static func path(size: CGFloat) -> Path {
        let r = size / 2, w = r * 0.28
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: w, y: -w))
        p.addQuadCurve(to: CGPoint(x: 0, y: r), control: CGPoint(x: w, y: w))
        p.addQuadCurve(to: CGPoint(x: -r, y: 0), control: CGPoint(x: -w, y: w))
        p.addQuadCurve(to: CGPoint(x: 0, y: -r), control: CGPoint(x: -w, y: -w))
        return p
    }
}

// MARK: - Sunburst + halo

/// Slowly turning rays behind a hero element (celebrations, the sealed medallion).
struct Sunburst: View {
    var color: Color = AppTheme.accentGold
    var rays: Int = 18
    var period: Double = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { tl in
            let spin = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period * 2 * .pi
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let R = max(size.width, size.height) * 0.75
                // Fade out by the inscribed circle so the canvas edge never shows as a hard line.
                let fade = min(size.width, size.height) / 2
                let step = 2 * Double.pi / Double(rays)
                for i in 0..<rays {
                    let a = Double(i) * step + spin
                    var ray = Path()
                    ray.move(to: c)
                    ray.addLine(to: CGPoint(x: c.x + cos(a - step * 0.22) * R, y: c.y + sin(a - step * 0.22) * R))
                    ray.addLine(to: CGPoint(x: c.x + cos(a + step * 0.22) * R, y: c.y + sin(a + step * 0.22) * R))
                    ray.closeSubpath()
                    ctx.fill(ray, with: .radialGradient(
                        Gradient(colors: [color.opacity(0.34), color.opacity(0.16), color.opacity(0)]),
                        center: c, startRadius: 0, endRadius: fade))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Glow backdrop

/// Three soft radial blooms drifting on slow sin/cos paths. Cheap (no blur), on-brand ambience.
struct GlowBackdrop: View {
    var colors: [Color] = [AppTheme.primaryGreen, Color(hex: "00BFA5"), AppTheme.accentGold]
    var intensity: Double = 0.22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let anchors: [(Double, Double, Double)] = [(0.2, 0.25, 0.11), (0.8, 0.35, 0.08), (0.5, 0.85, 0.06)]
                for (i, a) in anchors.enumerated() {
                    let x = size.width * (a.0 + 0.08 * sin(t * a.2 + Double(i)))
                    let y = size.height * (a.1 + 0.06 * cos(t * a.2 * 1.3 + Double(i)))
                    let r = max(size.width, size.height) * 0.55
                    let color = colors[i % colors.count]
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .radialGradient(Gradient(colors: [color.opacity(intensity), color.opacity(0)]),
                                                   center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Holographic sheen

/// A band of light sweeping across a card at an angle, like foil on a trading card.
struct HoloSheen: ViewModifier {
    var period: Double = 4.2
    var cornerRadius: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    let phase = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(colors: [.clear, .white.opacity(0.16), AppTheme.accentGold.opacity(0.18), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: w * 0.45)
                            .rotationEffect(.degrees(18))
                            .offset(x: -w * 0.6 + phase * w * 2.2)
                            .blendMode(.plusLighter)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func holoSheen(cornerRadius: CGFloat = 20) -> some View { modifier(HoloSheen(cornerRadius: cornerRadius)) }
}

// MARK: - Count-up number

/// A number that counts up (or down) when its value changes inside `withAnimation`.
struct CountUpText: View, Animatable {
    var value: Double
    var format: (Int) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(Int(value.rounded())))
            .monospacedDigit()
            .accessibilityLabel(format(Int(value.rounded())))
    }
}

// MARK: - Seal medallion

/// The brand mark for a sealed no-spend day: a minted gold coin with ring lettering, a spent-amount
/// centre, and the date. Drawn entirely in Canvas so it scales crisply and renders into share images.
struct SealMedallion: View {
    var ringText: String = String(localized: "NO-SPEND DAY")
    var center: String = 0.0.currencyFormatted
    var caption: String = Date().formatted(.dateTime.month(.abbreviated).day())
    var glow: Bool = true

    var body: some View {
        Canvas { ctx, size in
            let d = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = d / 2

            let outer = CGRect(x: c.x - r, y: c.y - r, width: d, height: d)
            // Coin body with a light source top-left.
            ctx.fill(Path(ellipseIn: outer), with: .radialGradient(
                Gradient(colors: [Color(hex: "FFF1A8"), Color(hex: "FFC83D"), Color(hex: "D98E04"), Color(hex: "8A5A00")]),
                center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.5))
            // Reeded edge.
            let teeth = 72
            for i in 0..<teeth {
                let a = Double(i) / Double(teeth) * 2 * .pi
                var tick = Path()
                tick.move(to: CGPoint(x: c.x + cos(a) * r * 0.95, y: c.y + sin(a) * r * 0.95))
                tick.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.995, y: c.y + sin(a) * r * 0.995))
                ctx.stroke(tick, with: .color(Color(hex: "7A4E00").opacity(0.55)), lineWidth: max(1, r * 0.012))
            }
            // Raised rims.
            ctx.stroke(Path(ellipseIn: outer.insetBy(dx: r * 0.08, dy: r * 0.08)),
                       with: .color(Color(hex: "FFF6CC").opacity(0.9)), lineWidth: r * 0.025)
            let inner = outer.insetBy(dx: r * 0.3, dy: r * 0.3)
            ctx.fill(Path(ellipseIn: inner), with: .linearGradient(
                Gradient(colors: [Color(hex: "0F3D2A"), Color(hex: "06251A")]),
                startPoint: CGPoint(x: inner.minX, y: inner.minY), endPoint: CGPoint(x: inner.maxX, y: inner.maxY)))
            ctx.stroke(Path(ellipseIn: inner), with: .color(Color(hex: "FFE082")), lineWidth: r * 0.03)

            // Ring lettering between the rims: the label arcs over the top, the brand arcs under the
            // bottom, and both read upright left-to-right like a real coin.
            let ringR = r * 0.815
            let ink = Color(hex: "3D2600")
            func arc(_ string: String, centeredAt mid: Double, upright bottom: Bool) {
                let maxArc = ringR * 2.5
                func glyphs(_ size: CGFloat) -> [(GraphicsContext.ResolvedText, CGFloat)] {
                    Array(string.uppercased(with: .current)).map { ch in
                        let t = ctx.resolve(Text(String(ch)).font(.system(size: size, weight: .heavy, design: .rounded))
                            .foregroundColor(ink))
                        return (t, t.measure(in: CGSize(width: size * 4, height: size * 4)).width + size * 0.14)
                    }
                }
                var size = r * 0.125
                var gs = glyphs(size)
                let total = gs.reduce(0) { $0 + $1.1 }
                if total > maxArc {
                    size *= maxArc / total
                    gs = glyphs(size)
                }
                let length = gs.reduce(0) { $0 + $1.1 }
                var run = -length / 2
                for (glyph, w) in gs {
                    let offset = Double((run + w / 2) / ringR)
                    let a = bottom ? mid - offset : mid + offset
                    var l = ctx
                    l.translateBy(x: c.x + cos(a) * ringR, y: c.y + sin(a) * ringR)
                    l.rotate(by: .radians(bottom ? a - .pi / 2 : a + .pi / 2))
                    l.draw(glyph, at: .zero)
                    run += w
                }
            }
            arc(ringText, centeredAt: -.pi / 2, upright: false)
            arc("SpendZero", centeredAt: .pi / 2, upright: true)
            for side in [0.0, Double.pi] {
                var l = ctx
                l.translateBy(x: c.x + cos(side) * ringR, y: c.y + sin(side) * ringR)
                l.draw(Text("★").font(.system(size: r * 0.1, weight: .heavy)).foregroundColor(ink), at: .zero)
            }

            // Centre: amount spent (zero) and the date.
            ctx.draw(Text(center).font(.system(size: r * 0.36, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen),
                     at: CGPoint(x: c.x, y: c.y - r * 0.04))
            ctx.draw(Text(caption.uppercased(with: .current)).font(.system(size: r * 0.1, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "FFE082")),
                     at: CGPoint(x: c.x, y: c.y + r * 0.25))

            // Specular glint on the inner bevel, clear of the ring lettering.
            var l = ctx
            l.opacity = 0.85
            l.translateBy(x: c.x + cos(-2.36) * r * 0.62, y: c.y + sin(-2.36) * r * 0.62)
            l.fill(Sparkle.path(size: r * 0.2), with: .color(.white))
        }
        .background {
            // Outside the canvas so the halo isn't clipped to the coin's square frame.
            if glow {
                GeometryReader { g in
                    let r = min(g.size.width, g.size.height) / 2
                    RadialGradient(colors: [AppTheme.accentGold.opacity(0.35), AppTheme.accentGold.opacity(0)],
                                   center: .center, startRadius: r * 0.6, endRadius: r * 1.3)
                        .frame(width: r * 2.6, height: r * 2.6)
                        .position(x: g.size.width / 2, y: g.size.height / 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Haptic beats

enum Beat {
    /// Two firm taps 130ms apart: a stamp landing.
    static func stamp() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { g.impactOccurred(intensity: 0.7) }
    }
    static func pop() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}
