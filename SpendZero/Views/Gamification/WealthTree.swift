import SwiftUI

/// A procedurally grown tree, unique per user (seeded from their game profile), that grows
/// continuously with level, bears gold coins as savings accumulate, and thrives or wilts with the
/// streak. Structure is computed once; only sway/twinkle/bob are animated per frame.
struct WealthTreeModel {
    struct Node {
        var parent: Int
        var relAngle: Double
        var length: CGFloat
        var width: CGFloat
        var depth: Int
        var grow: CGFloat
        var leaf = false
        var coin = false
        var phase: Double
    }

    let nodes: [Node]
    let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, phase: Double, speed: Double)]
    let grass: [(x: CGFloat, height: CGFloat, lean: Double)]

    static func build(seed: UInt64, growth: Double, vitality: Double, coins: Int) -> WealthTreeModel {
        var rng = SeededGenerator(seed: seed)
        let levels = 1.0 + growth * 5.4
        let maxDepth = Int(levels.rounded(.up))
        let frac = levels - floor(levels)
        let lastGrow = CGFloat(frac == 0 ? 1 : frac)
        var nodes: [Node] = []

        func add(parent: Int, rel: Double, len: CGFloat, width: CGFloat, depth: Int) {
            let g: CGFloat = depth == maxDepth ? lastGrow : 1
            let idx = nodes.count
            nodes.append(Node(parent: parent, relAngle: rel, length: len * g, width: width, depth: depth,
                              grow: g, phase: Double.random(in: 0...(2 * .pi), using: &rng)))
            guard depth < maxDepth else { return }
            let count = depth < 2 ? 2 : (Int.random(in: 0..<10, using: &rng) < 3 ? 3 : 2)
            for k in 0..<count {
                let spread = Double.random(in: 0.34...0.62, using: &rng)
                let base: Double = count == 2 ? (k == 0 ? -spread : spread) : [-spread, 0.04, spread][k]
                add(parent: idx,
                    rel: base + Double.random(in: -0.09...0.09, using: &rng),
                    len: len * CGFloat(Double.random(in: 0.7...0.83, using: &rng)),
                    width: width * 0.67,
                    depth: depth + 1)
            }
        }
        add(parent: -1, rel: Double.random(in: -0.05...0.05, using: &rng), len: 1, width: 1, depth: 1)

        // Leaves on tips and the last two tiers; a lapsed streak thins the canopy.
        var hasChild = Array(repeating: false, count: nodes.count)
        for n in nodes where n.parent >= 0 { hasChild[n.parent] = true }
        var leafIdx: [Int] = []
        for i in nodes.indices {
            let n = nodes[i]
            let candidate = !hasChild[i] || (n.depth >= max(2, maxDepth - 1))
            if candidate, Double.random(in: 0...1, using: &rng) < 0.3 + 0.7 * vitality {
                nodes[i].leaf = true
                leafIdx.append(i)
            }
        }
        if leafIdx.isEmpty, let last = nodes.indices.last { nodes[last].leaf = true; leafIdx = [last] }
        for i in leafIdx.shuffled(using: &rng).prefix(coins) { nodes[i].coin = true }

        let stars = (0..<22).map { _ in
            (x: CGFloat.random(in: 0.04...0.96, using: &rng), y: CGFloat.random(in: 0.04...0.55, using: &rng),
             size: CGFloat.random(in: 1...2.4, using: &rng), phase: Double.random(in: 0...6.28, using: &rng),
             speed: Double.random(in: 0.6...1.8, using: &rng))
        }
        let grass = (0..<26).map { _ in
            (x: CGFloat.random(in: 0.2...0.8, using: &rng), height: CGFloat.random(in: 4...11, using: &rng),
             lean: Double.random(in: -0.4...0.4, using: &rng))
        }
        return WealthTreeModel(nodes: nodes, stars: stars, grass: grass)
    }
}

struct WealthTreeCanvas: View {
    let seed: UInt64
    /// 0…1, continuous with level + XP progress.
    let growth: Double
    /// 0…1, how lush the canopy is (streak-driven).
    let vitality: Double
    let coins: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = false

    private static let lush: [Color] = [Color(hex: "00C853"), Color(hex: "00E676"), Color(hex: "1DE9B6"), Color(hex: "69F0AE"), Color(hex: "2ECC71")]
    private static let parched: [Color] = [Color(hex: "8D9440"), Color(hex: "A1A83A"), Color(hex: "B08D3C"), Color(hex: "6E7B32")]

    var body: some View {
        let model = WealthTreeModel.build(seed: seed, growth: growth, vitality: vitality, coins: coins)
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || !onScreen)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in draw(model, t: t, in: &ctx, size: size) }
        }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .accessibilityHidden(true)
    }

    private func draw(_ m: WealthTreeModel, t: Double, in ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let rect = CGRect(origin: .zero, size: size)

        // Sky
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(hex: "0B2A1E"), Color(hex: "0A1712"), Color(hex: "0A0E14")]),
                                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        for s in m.stars {
            let a = 0.15 + 0.55 * abs(sin(t * s.speed + s.phase))
            ctx.fill(Path(ellipseIn: CGRect(x: s.x * w, y: s.y * h, width: s.size, height: s.size)),
                     with: .color(.white.opacity(a)))
        }

        // Geometry pass. Lay the tree out in unit space (trunk = 1) without sway to measure it,
        // then pick a trunk length that keeps the whole canopy inside the card.
        let base = CGPoint(x: w / 2, y: h * 0.86)
        let clusterUnit = 0.66   // leaf-cluster radius relative to the trunk, used for padding
        var ux: (min: CGFloat, max: CGFloat) = (0, 0)
        var uyTop: CGFloat = 0
        do {
            var a = [Double](repeating: 0, count: m.nodes.count)
            var e = [CGPoint](repeating: .zero, count: m.nodes.count)
            for (i, n) in m.nodes.enumerated() {
                let pa = n.parent < 0 ? -Double.pi / 2 : a[n.parent]
                a[i] = pa + n.relAngle
                let s0 = n.parent < 0 ? .zero : e[n.parent]
                e[i] = CGPoint(x: s0.x + CGFloat(cos(a[i])) * n.length, y: s0.y + CGFloat(sin(a[i])) * n.length)
                let pad = n.leaf ? CGFloat(clusterUnit) : 0
                ux.min = min(ux.min, e[i].x - pad); ux.max = max(ux.max, e[i].x + pad)
                uyTop = min(uyTop, e[i].y - pad)
            }
        }
        let desired = h * (0.17 + 0.15 * growth)
        let fitV = (base.y - h * 0.06) / max(0.001, -uyTop)
        let fitH = (w * 0.46) / max(0.001, max(-ux.min, ux.max))
        let trunkLen = min(desired, fitV, fitH)
        let baseWidth = (3 + 10 * growth) * min(1, trunkLen / max(1, desired))
        var absAngle = [Double](repeating: 0, count: m.nodes.count)
        var start = [CGPoint](repeating: .zero, count: m.nodes.count)
        var end = [CGPoint](repeating: .zero, count: m.nodes.count)
        for (i, n) in m.nodes.enumerated() {
            let sway = sin(t * 1.25 + n.phase) * 0.018 * Double(n.depth)
            let parentAngle = n.parent < 0 ? -Double.pi / 2 : absAngle[n.parent]
            absAngle[i] = parentAngle + n.relAngle + sway
            start[i] = n.parent < 0 ? base : end[n.parent]
            let len = n.length * trunkLen
            end[i] = CGPoint(x: start[i].x + CGFloat(cos(absAngle[i])) * len, y: start[i].y + CGFloat(sin(absAngle[i])) * len)
        }
        let leafEnds = m.nodes.indices.filter { m.nodes[$0].leaf }.map { end[$0] }
        let canopy = leafEnds.isEmpty ? CGPoint(x: base.x, y: base.y - trunkLen)
            : CGPoint(x: leafEnds.map(\.x).reduce(0, +) / CGFloat(leafEnds.count),
                      y: leafEnds.map(\.y).reduce(0, +) / CGFloat(leafEnds.count))

        // Halo behind the canopy: gold when thriving, dim when parched.
        let haloR = trunkLen * (1.3 + growth)
        let haloColor = vitality > 0.5 ? AppTheme.accentGold : Color(hex: "8D9440")
        ctx.fill(Path(ellipseIn: CGRect(x: canopy.x - haloR, y: canopy.y - haloR, width: haloR * 2, height: haloR * 2)),
                 with: .radialGradient(Gradient(colors: [haloColor.opacity(0.22 * vitality + 0.05), .clear]),
                                       center: canopy, startRadius: 0, endRadius: haloR))

        // Ground mound + grass
        let mound = CGRect(x: w * 0.12, y: base.y - h * 0.045, width: w * 0.76, height: h * 0.16)
        ctx.fill(Path(ellipseIn: mound), with: .linearGradient(Gradient(colors: [Color(hex: "1C4A31"), Color(hex: "0B1A12")]),
                                                              startPoint: CGPoint(x: 0, y: mound.minY), endPoint: CGPoint(x: 0, y: mound.maxY)))
        for g in m.grass {
            var blade = Path()
            let gx = g.x * w
            let gy = base.y - h * 0.01 + abs(gx - w / 2) / w * h * 0.05
            blade.move(to: CGPoint(x: gx, y: gy))
            blade.addQuadCurve(to: CGPoint(x: gx + CGFloat(sin(g.lean + sin(t * 1.6 + Double(gx)) * 0.15)) * g.height, y: gy - g.height),
                               control: CGPoint(x: gx, y: gy - g.height * 0.6))
            ctx.stroke(blade, with: .color(Color(hex: "2E7D4F").opacity(0.9)), lineWidth: 1.2)
        }

        // Branches: tapered, lightly curved, bark-shaded.
        for (i, n) in m.nodes.enumerated() {
            let w0 = baseWidth * n.width
            let w1 = w0 * 0.66
            let a = absAngle[i]
            let nx = CGFloat(-sin(a)), ny = CGFloat(cos(a))
            let s = start[i], e = end[i]
            let bend = CGFloat(sin(n.phase)) * n.length * trunkLen * 0.08
            let mid = CGPoint(x: (s.x + e.x) / 2 + nx * bend, y: (s.y + e.y) / 2 + ny * bend)
            var p = Path()
            p.move(to: CGPoint(x: s.x + nx * w0 / 2, y: s.y + ny * w0 / 2))
            p.addQuadCurve(to: CGPoint(x: e.x + nx * w1 / 2, y: e.y + ny * w1 / 2),
                           control: CGPoint(x: mid.x + nx * (w0 + w1) / 4, y: mid.y + ny * (w0 + w1) / 4))
            p.addLine(to: CGPoint(x: e.x - nx * w1 / 2, y: e.y - ny * w1 / 2))
            p.addQuadCurve(to: CGPoint(x: s.x - nx * w0 / 2, y: s.y - ny * w0 / 2),
                           control: CGPoint(x: mid.x - nx * (w0 + w1) / 4, y: mid.y - ny * (w0 + w1) / 4))
            p.closeSubpath()
            ctx.fill(p, with: .linearGradient(Gradient(colors: [Color(hex: "8A5A34"), Color(hex: "5A3820"), Color(hex: "3B2414")]),
                                              startPoint: CGPoint(x: s.x + nx * w0, y: s.y + ny * w0),
                                              endPoint: CGPoint(x: s.x - nx * w0, y: s.y - ny * w0)))
            ctx.fill(Path(ellipseIn: CGRect(x: e.x - w1 / 2, y: e.y - w1 / 2, width: w1, height: w1)), with: .color(Color(hex: "4A2C17")))
        }

        // Leaves: a dark back layer then bright clusters, each leaf a rotated ellipse.
        let palette = vitality > 0.45 ? Self.lush : Self.parched
        let clusterR = min(8 + 15 * growth, Double(trunkLen) * clusterUnit)
        for pass in 0..<2 {
            for (i, n) in m.nodes.enumerated() where n.leaf {
                let r = clusterR * Double(n.grow) * (pass == 0 ? 1.25 : 1)
                let count = pass == 0 ? 6 : 11
                for k in 0..<count {
                    let ang = n.phase + Double(k) * 2 * .pi / Double(count)
                    let flutter = sin(t * 2.1 + n.phase + Double(k)) * 1.3
                    let c = CGPoint(x: end[i].x + CGFloat(cos(ang) * r * 0.55 + flutter),
                                    y: end[i].y + CGFloat(sin(ang) * r * 0.45))
                    var l = ctx
                    l.translateBy(x: c.x, y: c.y)
                    l.rotate(by: .radians(ang + 0.6))
                    let leaf = CGRect(x: -r * 0.5, y: -r * 0.28, width: r, height: r * 0.56)
                    if pass == 0 {
                        l.fill(Path(ellipseIn: leaf), with: .color(Color(hex: vitality > 0.45 ? "0B6B3A" : "4E5226").opacity(0.9)))
                    } else {
                        l.fill(Path(ellipseIn: leaf), with: .color(palette[(i + k) % palette.count].opacity(0.92)))
                        l.fill(Path(ellipseIn: leaf.insetBy(dx: r * 0.3, dy: r * 0.2)).offsetBy(dx: -r * 0.08, dy: -r * 0.05),
                               with: .color(.white.opacity(0.12)))
                    }
                }
            }
        }

        // Fallen leaves when parched.
        if vitality <= 0.45 {
            for k in 0..<6 {
                let x = w * (0.28 + 0.09 * CGFloat(k)), y = base.y + CGFloat(k % 2) * 4
                var l = ctx
                l.translateBy(x: x, y: y); l.rotate(by: .radians(Double(k) * 0.9))
                l.fill(Path(ellipseIn: CGRect(x: -5, y: -2.5, width: 10, height: 5)), with: .color(Self.parched[k % Self.parched.count].opacity(0.8)))
            }
        }

        // Gold coins hanging from the canopy.
        let coinR = 3.6 + 3.2 * growth
        for (i, n) in m.nodes.enumerated() where n.coin {
            let bob = sin(t * 2.2 + n.phase) * 1.4
            let anchor = CGPoint(x: end[i].x + CGFloat(cos(n.phase)) * clusterR * 0.3, y: end[i].y + clusterR * 0.35)
            let c = CGPoint(x: anchor.x, y: anchor.y + coinR + 3 + bob)
            var stem = Path(); stem.move(to: anchor); stem.addLine(to: CGPoint(x: c.x, y: c.y - coinR))
            ctx.stroke(stem, with: .color(Color(hex: "3B5E2B")), lineWidth: 0.8)
            let r = CGRect(x: c.x - coinR, y: c.y - coinR, width: coinR * 2, height: coinR * 2)
            ctx.fill(Path(ellipseIn: r.insetBy(dx: -coinR * 0.8, dy: -coinR * 0.8)),
                     with: .radialGradient(Gradient(colors: [AppTheme.accentGold.opacity(0.35), .clear]), center: c, startRadius: 0, endRadius: coinR * 1.8))
            ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [Color(hex: "FFF3B0"), Color(hex: "FFC400"), Color(hex: "B8860B")]),
                                                              center: CGPoint(x: c.x - coinR * 0.35, y: c.y - coinR * 0.35), startRadius: 0, endRadius: coinR * 1.4))
            ctx.stroke(Path(ellipseIn: r.insetBy(dx: coinR * 0.28, dy: coinR * 0.28)), with: .color(Color(hex: "8A6200").opacity(0.7)), lineWidth: 0.7)
        }

        // Rising sparkles when thriving.
        if vitality > 0.6 {
            for k in 0..<5 {
                let p = Double(k) * 1.37
                let rise = (t * 14 + p * 40).truncatingRemainder(dividingBy: 70)
                let x = canopy.x + CGFloat(sin(p * 3.1)) * haloR * 0.7
                let y = canopy.y + haloR * 0.2 - CGFloat(rise)
                var l = ctx
                l.opacity = max(0, 1 - rise / 70) * 0.9
                l.translateBy(x: x, y: y)
                l.fill(Sparkle.path(size: 7), with: .color(AppTheme.accentGold))
            }
        }
    }
}

extension UUID {
    /// Stable 64-bit seed (unlike `hashValue`, which is randomised per process).
    var seed64: UInt64 { withUnsafeBytes(of: uuid) { $0.loadUnaligned(as: UInt64.self) } }
}
