import SwiftUI

// The living wealth tree: a seeded procedural tree that grows with level, bears gold coins as
// savings accumulate and thrives or wilts with the streak — standing in a sky that follows the
// user's real local time and season.
//
// Performance notes: the tree's structure and its unit-space layout are built once per input
// change and cached; per-frame work reuses scratch buffers (no array allocations), colours are
// mixed from plain RGB triples (no hex parsing), and the timeline pauses offscreen. Reduce Motion
// renders one still frame (no wind, no falling particles, events appear without animation).

// MARK: - Colour

/// Plain linear-ish sRGB triple for cheap per-frame mixing.
struct TreeRGB {
    var r: Double, g: Double, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    static func mix(_ a: TreeRGB, _ b: TreeRGB, _ t: Double) -> TreeRGB {
        let t = min(1, max(0, t))
        return TreeRGB(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }
    func lit(_ l: TreeRGB) -> TreeRGB { TreeRGB(min(1, r * l.r), min(1, g * l.g), min(1, b * l.b)) }
    func scaled(_ k: Double) -> TreeRGB { TreeRGB(min(1, r * k), min(1, g * k), min(1, b * k)) }
    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
    func color(_ opacity: Double) -> Color { Color(.sRGB, red: r, green: g, blue: b, opacity: opacity) }
}

// MARK: - Season and local time

enum TreeSeason: String, CaseIterable { case winter, spring, summer, autumn }

/// Everything about "when" the tree is: season by local date (hemisphere from the locale's region),
/// approximate sunrise/sunset for the date, the real moon phase, and the local UTC offset.
struct TreeEnvironment: Equatable {
    var season: TreeSeason
    /// December: tiny string lights in the canopy (both hemispheres).
    var festive: Bool
    var sunrise: Double
    var sunset: Double
    /// 0 = new moon, 0.5 = full.
    var moonPhase: Double
    var utcOffset: Double
    var hourOverride: Double?
    /// DEBUG: seconds for one full day (time-lapse), 0 = real time.
    var timelapse: Double = 0

    private static let southernRegions: Set<String> = [
        "AU", "NZ", "ZA", "AR", "CL", "UY", "PY", "BR", "BO", "PE", "NA", "BW", "LS", "SZ", "MZ",
        "ZW", "ZM", "MG", "MU", "FJ", "NC", "PF", "WS", "TO", "RE", "MW", "AO"
    ]

    static func current(_ date: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> TreeEnvironment {
        let month = calendar.component(.month, from: date)
        let doy = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 172)
        let southern = southernRegions.contains(locale.region?.identifier ?? "")

        var season = Self.season(month: month, southern: southern)
        var festive = month == 12
        var hourOverride: Double?
        var timelapse = 0.0
        var moon = Self.moonPhase(date)
        var effectiveDoy = doy
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        func arg(_ k: String) -> String? { a.firstIndex(of: k).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil } }
        if let s = arg("-TreeSeason") {
            if s == "december" { season = .winter; festive = true; effectiveDoy = 350 }
            else if let v = TreeSeason(rawValue: s) {
                season = v; festive = false
                effectiveDoy = [TreeSeason.winter: 20.0, .spring: 110, .summer: 190, .autumn: 290][v] ?? doy
            }
        }
        if let h = arg("-TreeHour").flatMap(Double.init) { hourOverride = h }
        if let l = arg("-TreeTimelapse").flatMap(Double.init) { timelapse = l }
        if let m = arg("-TreeMoon").flatMap(Double.init) { moon = m }
        #endif

        // Day length for a mid-latitude (~40°) observer; solar noon shifts with daylight saving.
        let swing = southern ? -1.0 : 1.0
        let dayLength = 12 + 2.9 * swing * sin(2 * .pi * (effectiveDoy - 80) / 365)
        let noon = TimeZone.current.isDaylightSavingTime(for: date) ? 13.1 : 12.1
        return TreeEnvironment(season: season, festive: festive,
                               sunrise: noon - dayLength / 2, sunset: noon + dayLength / 2,
                               moonPhase: moon, utcOffset: Double(TimeZone.current.secondsFromGMT(for: date)),
                               hourOverride: hourOverride, timelapse: timelapse)
    }

    static func season(month: Int, southern: Bool) -> TreeSeason {
        let m = southern ? (month + 5) % 12 + 1 : month
        switch m {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }

    /// Fraction of the synodic month since a known new moon (2000-01-06 18:14 UTC).
    static func moonPhase(_ date: Date) -> Double {
        let days = (date.timeIntervalSince1970 - 947_182_440) / 86_400
        let p = (days / 29.530_588_853).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    /// Local hour (0..<24, fractional) at an absolute time.
    func hour(at t: TimeInterval) -> Double {
        if timelapse > 0 { return ((hourOverride ?? 6) + t / timelapse * 24).truncatingRemainder(dividingBy: 24) }
        if let hourOverride { return hourOverride }
        let local = (t + 978_307_200 + utcOffset).truncatingRemainder(dividingBy: 86_400)
        return (local < 0 ? local + 86_400 : local) / 3600
    }
}

/// The sky and light for one instant.
struct TreeSky {
    var top: TreeRGB, mid: TreeRGB, horizon: TreeRGB
    /// Multiplier applied to everything lit by the sky (tree, hills, ground).
    var ambient: TreeRGB
    /// 0 = full day, 1 = deep night.
    var night: Double
    /// Golden-hour amount, 0…1.
    var warmth: Double
    /// Sun elevation proxy, -1…1 (negative below the horizon).
    var elevation: Double
    /// 0…1 across the day (sun) or the night (moon).
    var arc: Double
    var isDay: Bool

    private struct Key { var top: UInt32, mid: UInt32, horizon: UInt32, ambient: TreeRGB }
    private static let nightKey = Key(top: 0x03060F, mid: 0x0A1530, horizon: 0x1A2C52, ambient: TreeRGB(0.34, 0.42, 0.66))
    private static let dawnKey = Key(top: 0x1B2452, mid: 0x5D4C82, horizon: 0xF09482, ambient: TreeRGB(0.66, 0.58, 0.72))
    private static let duskKey = Key(top: 0x1A1E4A, mid: 0x744070, horizon: 0xF7834E, ambient: TreeRGB(0.74, 0.54, 0.56))
    private static let goldenKey = Key(top: 0x4673B0, mid: 0xE3AE7E, horizon: 0xFFCB76, ambient: TreeRGB(1.10, 0.90, 0.68))
    private static let dayKey = Key(top: 0x2A73C4, mid: 0x62ACE2, horizon: 0xBFE4F2, ambient: TreeRGB(1, 1, 1))

    static func at(hour h: Double, env: TreeEnvironment) -> TreeSky {
        let sr = env.sunrise, ss = env.sunset
        let isDay = h >= sr && h <= ss
        let arc: Double, e: Double, morning: Bool
        if isDay {
            arc = (h - sr) / (ss - sr)
            e = sin(.pi * arc)
            morning = arc < 0.5
        } else {
            let nightLen = 24 - (ss - sr)
            arc = ((h - ss + 24).truncatingRemainder(dividingBy: 24)) / nightLen
            e = -sin(.pi * arc)
            morning = arc > 0.5
        }
        let twilight = morning ? dawnKey : duskKey
        // Piecewise blend over elevation: night → twilight → golden → day.
        let stops: [(Double, Key)] = [(-0.3, nightKey), (-0.07, twilight), (0.09, goldenKey), (0.42, dayKey)]
        var lo = stops[0], hi = stops[0]
        if e <= stops[0].0 { lo = stops[0]; hi = stops[0] }
        else if e >= stops[3].0 { lo = stops[3]; hi = stops[3] }
        else {
            for i in 0..<3 where e >= stops[i].0 && e <= stops[i + 1].0 { lo = stops[i]; hi = stops[i + 1] }
        }
        let f = hi.0 == lo.0 ? 0 : (e - lo.0) / (hi.0 - lo.0)
        let s = f * f * (3 - 2 * f)
        func m(_ a: UInt32, _ b: UInt32) -> TreeRGB { .mix(TreeRGB(a), TreeRGB(b), s) }
        let night = min(1, max(0, (-e - 0.02) / 0.25))
        let warmth = max(0, 1 - abs(e - 0.07) / 0.2)
        return TreeSky(top: m(lo.1.top, hi.1.top), mid: m(lo.1.mid, hi.1.mid), horizon: m(lo.1.horizon, hi.1.horizon),
                       ambient: .mix(lo.1.ambient, hi.1.ambient, s), night: night, warmth: warmth,
                       elevation: e, arc: arc, isDay: isDay)
    }
}

// MARK: - Model

/// Structure and unit-space layout of a user's tree. Built once per input change.
struct WealthTreeModel {
    struct Node {
        var parent: Int
        var relAngle: Double
        var length: CGFloat
        var width: CGFloat
        var depth: Int
        var grow: CGFloat
        var leaf = false
        /// Order in which this leaf cluster receives a coin (-1 = never).
        var coinRank = -1
        var phase: Double
    }

    struct Particle { var x: Double, y: Double, size: Double, speed: Double, phase: Double, spin: Double }
    struct Garland { var nodes: [Int] }

    let nodes: [Node]
    /// Leaf-cluster node indices (drawing order).
    let leaves: [Int]
    /// Unit-space bounds of the canopy (trunk = 1), used to fit the tree to the card.
    let unitMinX: CGFloat, unitMaxX: CGFloat, unitTop: CGFloat
    /// Unit-space rest positions of each node's tip.
    let unitEnd: [CGPoint]
    /// Node indices where milestone birds perch, best perch first.
    let perches: [Int]
    let garlands: [Garland]
    let stars: [Particle]
    let grass: [Particle]
    let clouds: [Particle]
    let fallers: [Particle]
    let fireflies: [Particle]
    let groundLeaves: [Particle]
    let hills: [Double]

    static let clusterUnit: CGFloat = 0.66

    static func build(seed: UInt64, growth: Double, vitality: Double) -> WealthTreeModel {
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
        for (rank, i) in leafIdx.shuffled(using: &rng).enumerated() { nodes[i].coinRank = rank }

        // Unit-space rest layout.
        var angle = [Double](repeating: 0, count: nodes.count)
        var end = [CGPoint](repeating: .zero, count: nodes.count)
        var minX: CGFloat = 0, maxX: CGFloat = 0, top: CGFloat = 0
        for (i, n) in nodes.enumerated() {
            let pa = n.parent < 0 ? -Double.pi / 2 : angle[n.parent]
            angle[i] = pa + n.relAngle
            let s0 = n.parent < 0 ? CGPoint.zero : end[n.parent]
            end[i] = CGPoint(x: s0.x + CGFloat(cos(angle[i])) * n.length, y: s0.y + CGFloat(sin(angle[i])) * n.length)
            let pad = n.leaf ? clusterUnit : 0
            minX = min(minX, end[i].x - pad); maxX = max(maxX, end[i].x + pad)
            top = min(top, end[i].y - pad)
        }

        // Perches: sturdy, fairly level mid-tree branches, spread left/right/centre.
        var perchCandidates = nodes.indices.filter { i in
            let n = nodes[i]
            return n.depth >= 2 && n.depth <= 4 && abs(cos(angle[i])) > 0.42 && sin(angle[i]) < 0.2
        }
        if perchCandidates.isEmpty { perchCandidates = nodes.indices.filter { nodes[$0].depth >= 2 } }
        var perches: [Int] = []
        if !perchCandidates.isEmpty {
            let byX = perchCandidates.sorted { end[$0].x < end[$1].x }
            for pick in [byX.last!, byX.first!, byX[byX.count / 2]] where !perches.contains(pick) { perches.append(pick) }
        }

        // String-light garlands: two tiers across the canopy, left to right.
        let sortedLeaves = leafIdx.sorted { end[$0].y < end[$1].y }
        var garlands: [Garland] = []
        if sortedLeaves.count >= 4 {
            let half = sortedLeaves.count / 2
            for tier in [Array(sortedLeaves[half...]), Array(sortedLeaves[(half / 3)..<half])] where tier.count >= 2 {
                let byX = tier.sorted { end[$0].x < end[$1].x }
                let step = max(1, byX.count / 5)
                var chain = stride(from: 0, to: byX.count, by: step).map { byX[$0] }
                if chain.last != byX.last { chain.append(byX.last!) }
                if chain.count >= 2 { garlands.append(Garland(nodes: chain)) }
            }
        }

        func particles(_ n: Int, _ make: (inout SeededGenerator) -> Particle) -> [Particle] {
            (0..<n).map { _ in make(&rng) }
        }
        let stars = particles(40) { r in
            Particle(x: .random(in: 0.02...0.98, using: &r), y: .random(in: 0.02...0.62, using: &r),
                     size: .random(in: 0.8...2.2, using: &r), speed: .random(in: 0.6...1.8, using: &r),
                     phase: .random(in: 0...6.28, using: &r), spin: 0)
        }
        let grass = particles(46) { r in
            Particle(x: .random(in: 0.0...1.0, using: &r), y: .random(in: 0...1, using: &r),
                     size: .random(in: 4...11, using: &r), speed: 0,
                     phase: .random(in: -0.4...0.4, using: &r), spin: 0)
        }
        let clouds = particles(4) { r in
            Particle(x: .random(in: 0...1, using: &r), y: .random(in: 0.08...0.36, using: &r),
                     size: .random(in: 0.7...1.25, using: &r), speed: .random(in: 0.004...0.009, using: &r),
                     phase: .random(in: 0...6.28, using: &r), spin: .random(in: 0...1, using: &r))
        }
        let fallers = particles(64) { r in
            Particle(x: .random(in: 0...1, using: &r), y: .random(in: 0...1, using: &r),
                     size: .random(in: 0.6...1.6, using: &r), speed: .random(in: 0.6...1.4, using: &r),
                     phase: .random(in: 0...6.28, using: &r), spin: .random(in: -1...1, using: &r))
        }
        let fireflies = particles(11) { r in
            Particle(x: .random(in: 0.1...0.9, using: &r), y: .random(in: 0.45...0.85, using: &r),
                     size: .random(in: 1.4...2.4, using: &r), speed: .random(in: 0.3...0.8, using: &r),
                     phase: .random(in: 0...6.28, using: &r), spin: .random(in: 0...6.28, using: &r))
        }
        let groundLeaves = particles(16) { r in
            Particle(x: .random(in: 0.2...0.8, using: &r), y: .random(in: 0...1, using: &r),
                     size: .random(in: 0.8...1.2, using: &r), speed: 0,
                     phase: .random(in: 0...6.28, using: &r), spin: .random(in: 0...1, using: &r))
        }
        let hills = (0..<6).map { _ in Double.random(in: 0...6.28, using: &rng) }

        return WealthTreeModel(nodes: nodes, leaves: leafIdx, unitMinX: minX, unitMaxX: maxX, unitTop: top,
                               unitEnd: end, perches: perches, garlands: garlands, stars: stars, grass: grass,
                               clouds: clouds, fallers: fallers, fireflies: fireflies, groundLeaves: groundLeaves,
                               hills: hills)
    }
}

// MARK: - Events

/// A one-off moment played on the tree: a leaf tumbling off (spending since the last visit) or a
/// gold coin popping onto a branch (a sealed day).
struct WealthTreeEvent: Identifiable, Equatable {
    enum Kind: Equatable { case leafFall, coinPop }
    let id: Int
    let kind: Kind
    /// Absolute start (`timeIntervalSinceReferenceDate`).
    let start: TimeInterval

    static let leafDuration: Double = 6.5
    static let coinDuration: Double = 2.4
    var duration: Double { kind == .leafFall ? Self.leafDuration : Self.coinDuration }
}

/// Lightweight hook for the rest of the app to queue tree moments. Queued events play the next time
/// a wealth tree is on screen (immediately if one is visible). `MoneyTreeView` also detects new
/// spending logs and sealed days on its own, so calling these is optional; duplicates are merged.
@MainActor
@Observable
final class WealthTreeEvents {
    static let shared = WealthTreeEvents()

    private(set) var pendingLeafFalls = 0
    private(set) var pendingCoinPops = 0

    private init() {}

    /// A purchase was logged: a leaf will detach and tumble down.
    func spendingLogged() { pendingLeafFalls = min(3, pendingLeafFalls + 1) }
    /// A no-spend day was sealed: a coin will pop onto a branch.
    func daySealed() { pendingCoinPops = min(3, pendingCoinPops + 1) }

    /// Takes everything queued (called by the tree when it is visible).
    func drain() -> (leafFalls: Int, coinPops: Int) {
        defer { pendingLeafFalls = 0; pendingCoinPops = 0 }
        return (pendingLeafFalls, pendingCoinPops)
    }
}

// MARK: - Canvas

struct WealthTreeCanvas: View {
    let seed: UInt64
    /// 0…1, continuous with level + XP progress.
    let growth: Double
    /// 0…1, how lush the canopy is (streak-driven).
    let vitality: Double
    let coins: Int
    /// Current streak; birds perch at 7, 30 and 100 days.
    var streak: Int = 0
    var events: [WealthTreeEvent] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = false
    @State private var cache = WealthTreeCache()

    var body: some View {
        let model = cache.model(seed: seed, growth: growth, vitality: vitality)
        let env = cache.environment()
        let birds = Self.birdCount(streak: streak)
        let input = WealthTreeRenderer.Input(model: model, env: env, growth: growth, vitality: vitality,
                                             coins: coins, birds: birds, events: events, still: reduceMotion)
        Group {
            if reduceMotion {
                // One still frame, refreshed each minute so the sky still follows the clock.
                TimelineView(.periodic(from: .now, by: 60)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in WealthTreeRenderer.draw(input, t: t, scratch: cache.scratch, in: &ctx, size: size) }
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !onScreen)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in WealthTreeRenderer.draw(input, t: t, scratch: cache.scratch, in: &ctx, size: size) }
                }
            }
        }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .accessibilityHidden(true)
    }

    static func birdCount(streak: Int) -> Int {
        #if DEBUG
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-TreeStreak"), i + 1 < a.count, let s = Int(a[i + 1]) {
            return s >= 100 ? 3 : s >= 30 ? 2 : s >= 7 ? 1 : 0
        }
        #endif
        return streak >= 100 ? 3 : streak >= 30 ? 2 : streak >= 7 ? 1 : 0
    }
}

/// Reference-type cache so body re-evaluations reuse the built tree and per-frame buffers.
final class WealthTreeCache {
    private var key: (UInt64, Double, Double)?
    private var cached: WealthTreeModel?
    private var envStamp: Date = .distantPast
    private var cachedEnv: TreeEnvironment?
    let scratch = WealthTreeScratch()

    func model(seed: UInt64, growth: Double, vitality: Double) -> WealthTreeModel {
        if let cached, let key, key == (seed, growth, vitality) { return cached }
        let m = WealthTreeModel.build(seed: seed, growth: growth, vitality: vitality)
        cached = m
        key = (seed, growth, vitality)
        scratch.reserve(m.nodes.count)
        return m
    }

    func environment() -> TreeEnvironment {
        if let cachedEnv, Date().timeIntervalSince(envStamp) < 600 { return cachedEnv }
        let e = TreeEnvironment.current()
        cachedEnv = e
        envStamp = Date()
        return e
    }
}

/// Per-frame buffers, sized once per tree.
final class WealthTreeScratch {
    var angle: [Double] = []
    var start: [CGPoint] = []
    var end: [CGPoint] = []
    var width: [CGFloat] = []

    func reserve(_ n: Int) {
        guard angle.count != n else { return }
        angle = .init(repeating: 0, count: n)
        start = .init(repeating: .zero, count: n)
        end = .init(repeating: .zero, count: n)
        width = .init(repeating: 0, count: n)
    }
}

// MARK: - Renderer

enum WealthTreeRenderer {
    struct Input {
        let model: WealthTreeModel
        let env: TreeEnvironment
        let growth: Double
        let vitality: Double
        let coins: Int
        let birds: Int
        let events: [WealthTreeEvent]
        let still: Bool
    }

    // Palettes
    private static let summer: [TreeRGB] = [TreeRGB(0x00C853), TreeRGB(0x00E676), TreeRGB(0x1DE9B6), TreeRGB(0x69F0AE), TreeRGB(0x2ECC71)]
    private static let spring: [TreeRGB] = [TreeRGB(0x7ED957), TreeRGB(0x4CC96B), TreeRGB(0xA8E46E), TreeRGB(0x36B565), TreeRGB(0x92E08A)]
    private static let autumn: [TreeRGB] = [TreeRGB(0xF2A93B), TreeRGB(0xE8772E), TreeRGB(0xD5512A), TreeRGB(0xF7C948), TreeRGB(0xB8662A), TreeRGB(0x9DB34A)]
    private static let winter: [TreeRGB] = [TreeRGB(0x1F7A55), TreeRGB(0x2A8C63), TreeRGB(0x17694A), TreeRGB(0x3A9A70)]
    private static let parched: [TreeRGB] = [TreeRGB(0x8D9440), TreeRGB(0xA1A83A), TreeRGB(0xB08D3C), TreeRGB(0x6E7B32)]
    private static let bulbs: [TreeRGB] = [TreeRGB(0xFFD740), TreeRGB(0xFF5252), TreeRGB(0x69F0AE), TreeRGB(0x82B1FF), TreeRGB(0xFFF3C4)]
    private static let blossom: [TreeRGB] = [TreeRGB(0xFFC4DC), TreeRGB(0xFFE6F0), TreeRGB(0xFFA3C8)]

    /// A pointed leaf along +x, unit length.
    private static let leafPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: -0.5, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0.5, y: 0), control: CGPoint(x: -0.05, y: -0.46))
        p.addQuadCurve(to: CGPoint(x: -0.5, y: 0), control: CGPoint(x: -0.05, y: 0.46))
        p.closeSubpath()
        return p
    }()

    /// Five round petals, unit radius.
    private static let flowerPath: Path = {
        var p = Path()
        for k in 0..<5 {
            let a = Double(k) * 2 * .pi / 5 - .pi / 2
            p.addEllipse(in: CGRect(x: cos(a) * 0.48 - 0.36, y: sin(a) * 0.48 - 0.36, width: 0.72, height: 0.72))
        }
        return p
    }()

    // MARK: Wind

    private static func hash(_ i: Int) -> Double {
        var x = UInt64(bitPattern: Int64(i)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 29; x &*= 0xBF58_476D_1CE4_E5B9; x ^= x >> 32
        return Double(x & 0xFFFFFF) / Double(0xFFFFFF) * 2 - 1
    }

    /// Smooth 1D value noise in -1…1.
    private static func noise(_ x: Double) -> Double {
        let i = floor(x), f = x - i
        let u = f * f * f * (f * (f * 6 - 15) + 10)
        let a = hash(Int(i)), b = hash(Int(i) + 1)
        return a + (b - a) * u
    }

    /// Gusting wind, mostly blowing rightwards: roughly -0.2…1.
    private static func wind(_ t: Double) -> Double {
        let g = 0.55 * noise(t * 0.33) + 0.3 * noise(t * 0.87 + 17) + 0.15 * noise(t * 2.3 + 41)
        return 0.4 + 0.6 * g
    }

    // MARK: Draw

    static func draw(_ input: Input, t rawT: Double, scratch: WealthTreeScratch, in ctx: inout GraphicsContext, size: CGSize) {
        let m = input.model
        let env = input.env
        let still = input.still
        // Animation clock: kept small for float precision; frozen under Reduce Motion.
        let t = still ? 0 : rawT.truncatingRemainder(dividingBy: 86_400)
        let sky = TreeSky.at(hour: env.hour(at: rawT), env: env)
        let w = size.width, h = size.height
        let season = env.season
        let windAmp = still ? 0 : (season == .autumn ? 1.25 : season == .summer ? 0.85 : 1)
        let gustNow = still ? 0.3 : wind(t)

        let horizonY = h * 0.74
        let groundY = h * 0.86

        drawSky(sky, m: m, env: env, t: t, w: w, h: h, horizonY: horizonY, in: &ctx)
        drawLandscape(sky, m: m, season: season, t: t, w: w, h: h, horizonY: horizonY, groundY: groundY, in: &ctx)

        // --- Tree layout (fit to card, then sway) ---
        scratch.reserve(m.nodes.count)
        let base = CGPoint(x: w / 2, y: groundY + h * 0.01)
        let desired = h * (0.17 + 0.15 * input.growth)
        let fitV = (base.y - h * 0.07) / max(0.001, -m.unitTop)
        let fitH = (w * 0.44) / max(0.001, max(-m.unitMinX, m.unitMaxX))
        let trunkLen = min(desired, fitV, fitH)
        let baseWidth = (3 + 10 * input.growth) * min(1, trunkLen / max(1, desired))
        var canopySum = CGPoint.zero
        var leafCount: CGFloat = 0
        for (i, n) in m.nodes.enumerated() {
            let d = Double(n.depth)
            let lag = d * 0.11 + n.phase * 0.04
            let local = wind(t - lag)
            let flex = 0.0026 * pow(d, 1.35) * windAmp
            let sway = flex * (local * 0.95 + 0.4 * sin(t * (1.6 + 0.45 * d) + n.phase) * (0.35 + abs(local)))
            let parentAngle = n.parent < 0 ? -Double.pi / 2 : scratch.angle[n.parent]
            let a = parentAngle + n.relAngle + sway
            scratch.angle[i] = a
            let s = n.parent < 0 ? base : scratch.end[n.parent]
            scratch.start[i] = s
            let len = n.length * trunkLen
            let e = CGPoint(x: s.x + CGFloat(cos(a)) * len, y: s.y + CGFloat(sin(a)) * len)
            scratch.end[i] = e
            scratch.width[i] = baseWidth * n.width
            if n.leaf { canopySum.x += e.x; canopySum.y += e.y; leafCount += 1 }
        }
        let canopy = leafCount > 0 ? CGPoint(x: canopySum.x / leafCount, y: canopySum.y / leafCount)
            : CGPoint(x: base.x, y: base.y - trunkLen)

        // Light comes from the sun (day) or moon (night); default upper-left.
        let lightPos = celestialPosition(sky, w: w, horizonY: horizonY)
        var ldx = Double(lightPos.x - canopy.x), ldy = Double(lightPos.y - canopy.y)
        let ll = max(0.001, (ldx * ldx + ldy * ldy).squareRoot())
        ldx /= ll; ldy /= ll

        // Shadow on the ground, cast away from the light.
        let shadowW = trunkLen * (1.6 + CGFloat(input.growth))
        let shadowShift = CGFloat(-ldx) * shadowW * 0.35
        let shadowRect = CGRect(x: base.x - shadowW / 2 + shadowShift, y: base.y - 5, width: shadowW, height: 12)
        ctx.fill(Path(ellipseIn: shadowRect),
                 with: .radialGradient(Gradient(colors: [Color.black.opacity(0.34 - 0.14 * sky.night), .clear]),
                                       center: CGPoint(x: shadowRect.midX, y: shadowRect.midY), startRadius: 0, endRadius: shadowW / 2))

        // Halo behind the canopy: gold when thriving, dim when parched; strongest at night.
        let haloR = trunkLen * (1.3 + CGFloat(input.growth))
        let haloColor = input.vitality > 0.5 ? TreeRGB(0xFFD740) : TreeRGB(0x8D9440)
        let haloA = (0.22 * input.vitality + 0.05) * (0.35 + 0.65 * sky.night + 0.4 * sky.warmth)
        ctx.fill(Path(ellipseIn: CGRect(x: canopy.x - haloR, y: canopy.y - haloR, width: haloR * 2, height: haloR * 2)),
                 with: .radialGradient(Gradient(colors: [haloColor.color(haloA), .clear]),
                                       center: canopy, startRadius: 0, endRadius: haloR))

        drawGrass(sky, m: m, season: season, t: t, gust: gustNow * windAmp, w: w, groundY: groundY, in: &ctx)
        drawBranches(sky, m: m, season: season, scratch: scratch, trunkLen: trunkLen, ldx: ldx, in: &ctx)

        // --- Foliage ---
        let palette: [TreeRGB]
        if input.vitality <= 0.45 { palette = parched }
        else {
            switch season {
            case .spring: palette = spring
            case .summer: palette = summer
            case .autumn: palette = autumn
            case .winter: palette = winter
            }
        }
        let density: Double = season == .winter ? 0.72 : season == .autumn ? 0.86 : 1
        let clusterR = min(8 + 15 * input.growth, Double(trunkLen * WealthTreeModel.clusterUnit))
        drawFoliage(sky, m: m, palette: palette, season: season, density: density, t: t, gust: gustNow * windAmp,
                    still: still, scratch: scratch, clusterR: clusterR, ldx: ldx, ldy: ldy, in: &ctx)
        if season == .winter { drawSnowCaps(sky, m: m, scratch: scratch, clusterR: clusterR, in: &ctx) }
        if env.festive { drawLights(sky, m: m, t: t, still: still, scratch: scratch, clusterR: clusterR, in: &ctx) }

        drawCoins(input, m: m, t: t, rawT: rawT, still: still, scratch: scratch, clusterR: clusterR, sky: sky, in: &ctx)
        if input.birds > 0 { drawBirds(input.birds, m: m, sky: sky, t: t, still: still, scratch: scratch, trunkLen: trunkLen, in: &ctx) }

        if !still {
            drawWeather(sky, m: m, season: season, t: t, w: w, h: h, groundY: groundY, palette: palette, in: &ctx)
            for ev in input.events where ev.kind == .leafFall {
                let age = rawT - ev.start
                guard age >= 0, age < ev.duration else { continue }
                drawFallingLeaf(ev, age: age, m: m, scratch: scratch, palette: palette, sky: sky, clusterR: clusterR,
                                gust: gustNow * windAmp, groundY: groundY, in: &ctx)
            }
            // Rising sparkles when thriving.
            if input.vitality > 0.6 {
                for k in 0..<5 {
                    let p = Double(k) * 1.37
                    let rise = (t * 14 + p * 40).truncatingRemainder(dividingBy: 70)
                    let x = canopy.x + CGFloat(sin(p * 3.1)) * haloR * 0.7
                    let y = canopy.y + haloR * 0.2 - CGFloat(rise)
                    var l = ctx
                    l.opacity = max(0, 1 - rise / 70) * (0.5 + 0.4 * sky.night)
                    l.translateBy(x: x, y: y)
                    l.fill(Sparkle.path(size: 7), with: .color(Color(.sRGB, red: 1, green: 0.84, blue: 0.25)))
                }
            }
        }

        // Blend the bottom edge into the card.
        ctx.fill(Path(CGRect(x: 0, y: h * 0.9, width: w, height: h * 0.1)),
                 with: .linearGradient(Gradient(colors: [.clear, Color(.sRGB, red: 0.04, green: 0.055, blue: 0.08, opacity: 0.55)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.9), endPoint: CGPoint(x: 0, y: h)))
    }

    /// Sun by day, moon by night, on an arc above the horizon.
    private static func celestialPosition(_ sky: TreeSky, w: CGFloat, horizonY: CGFloat) -> CGPoint {
        let x = w * (0.1 + 0.8 * CGFloat(sky.arc))
        let lift = CGFloat(sin(.pi * sky.arc))
        return CGPoint(x: x, y: horizonY - lift * horizonY * 0.78 + 4)
    }

    // MARK: Sky

    private static func drawSky(_ sky: TreeSky, m: WealthTreeModel, env: TreeEnvironment, t: Double,
                                w: CGFloat, h: CGFloat, horizonY: CGFloat, in ctx: inout GraphicsContext) {
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [.init(color: sky.top.color, location: 0), .init(color: sky.mid.color, location: 0.5),
                             .init(color: sky.horizon.color, location: 0.76), .init(color: sky.horizon.scaled(0.8).color, location: 1)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // Stars
        if sky.night > 0.02 {
            for s in m.stars {
                let tw = 0.35 + 0.65 * abs(sin(t * s.speed + s.phase))
                let a = tw * sky.night * (1 - s.y * 0.8)
                let r = CGRect(x: s.x * w, y: s.y * h, width: s.size, height: s.size)
                ctx.fill(Path(ellipseIn: r), with: .color(.white.opacity(a)))
                if s.size > 1.9 {
                    var l = ctx
                    l.opacity = a * 0.7
                    l.translateBy(x: r.midX, y: r.midY)
                    l.fill(Sparkle.path(size: s.size * 3.2), with: .color(.white))
                }
            }
        }

        let pos = celestialPosition(sky, w: w, horizonY: horizonY)
        if sky.isDay {
            // Sun: warm and large near the horizon, small and white overhead.
            let warm = TreeRGB.mix(TreeRGB(0xFFF8E1), TreeRGB(0xFFB04A), sky.warmth + max(0, 0.25 - sky.elevation))
            let r = h * (0.05 + 0.02 * sky.warmth)
            let glowR = h * (0.38 + 0.25 * sky.warmth)
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x - glowR, y: pos.y - glowR, width: glowR * 2, height: glowR * 2)),
                     with: .radialGradient(Gradient(colors: [warm.color(0.55 + 0.25 * sky.warmth), warm.color(0.12), .clear]),
                                           center: pos, startRadius: 0, endRadius: glowR))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)),
                     with: .radialGradient(Gradient(colors: [.white, warm.color]), center: pos, startRadius: 0, endRadius: r))
        } else if sky.night > 0.05 {
            drawMoon(at: pos, r: h * 0.042, phase: env.moonPhase, sky: sky, in: &ctx)
        }

        // Clouds drift slowly with the wind.
        let cloudBase = TreeRGB.mix(TreeRGB(0xFFFFFF), sky.horizon, 0.25 + 0.45 * sky.warmth).lit(sky.ambient)
        let cloudA = 0.5 - 0.22 * sky.night
        for c in m.clouds {
            let span = w * 1.5
            let cx = (CGFloat(c.x) * span + CGFloat(t * c.speed) * w).truncatingRemainder(dividingBy: span) - w * 0.25
            let cy = CGFloat(c.y) * h
            let s = CGFloat(c.size) * h * 0.075
            for k in 0..<5 {
                let fx = CGFloat(k) - 2
                let pr = s * (1.25 - abs(fx) * 0.17 + CGFloat(sin(c.phase + Double(k) * 1.9)) * 0.15)
                let pc = CGPoint(x: cx + fx * s * 0.9, y: cy - pr * 0.25 + abs(fx) * s * 0.12)
                ctx.fill(Path(ellipseIn: CGRect(x: pc.x - pr, y: pc.y - pr * 0.7, width: pr * 2, height: pr * 1.4)),
                         with: .radialGradient(Gradient(colors: [cloudBase.color(cloudA), cloudBase.color(cloudA * 0.4), .clear]),
                                               center: pc, startRadius: 0, endRadius: pr))
            }
        }
    }

    private static func drawMoon(at c: CGPoint, r: CGFloat, phase: Double, sky: TreeSky, in ctx: inout GraphicsContext) {
        let glowR = r * 6
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - glowR, y: c.y - glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [Color(.sRGB, red: 0.8, green: 0.86, blue: 1, opacity: 0.22 * sky.night), .clear]),
                                       center: c, startRadius: r, endRadius: glowR))
        let disc = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        // Earthshine on the dark limb.
        ctx.fill(Path(ellipseIn: disc), with: .color(Color(.sRGB, red: 0.55, green: 0.62, blue: 0.8, opacity: 0.16 * sky.night)))

        let waxing = phase < 0.5
        let k = cos(2 * .pi * phase)
        let side: CGFloat = waxing ? 1 : -1
        var lit = Path()
        let steps = 20
        for i in 0...steps {
            let th = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            let p = CGPoint(x: c.x + side * r * CGFloat(cos(th)), y: c.y + r * CGFloat(sin(th)))
            if i == 0 { lit.move(to: p) } else { lit.addLine(to: p) }
        }
        for i in 0...steps {
            let th = Double.pi / 2 - Double.pi * Double(i) / Double(steps)
            lit.addLine(to: CGPoint(x: c.x + side * r * CGFloat(k * cos(th)), y: c.y + r * CGFloat(sin(th))))
        }
        lit.closeSubpath()
        var l = ctx
        l.opacity = 0.35 + 0.65 * sky.night
        l.fill(lit, with: .radialGradient(Gradient(colors: [Color(.sRGB, red: 1, green: 0.98, blue: 0.9), Color(.sRGB, red: 0.86, green: 0.87, blue: 0.82)]),
                                          center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.3), startRadius: 0, endRadius: r * 1.6))
        // A couple of maria for texture, clipped to the lit side.
        l.clip(to: lit)
        for (dx, dy, rr) in [(-0.3, -0.2, 0.28), (0.25, 0.15, 0.22), (-0.05, 0.42, 0.16)] {
            l.fill(Path(ellipseIn: CGRect(x: c.x + r * dx - r * rr, y: c.y + r * dy - r * rr, width: r * rr * 2, height: r * rr * 2)),
                   with: .color(Color(.sRGB, red: 0.7, green: 0.7, blue: 0.68, opacity: 0.35)))
        }
    }

    // MARK: Landscape

    private static func drawLandscape(_ sky: TreeSky, m: WealthTreeModel, season: TreeSeason, t: Double,
                                      w: CGFloat, h: CGFloat, horizonY: CGFloat, groundY: CGFloat, in ctx: inout GraphicsContext) {
        let snowy = season == .winter
        let ph = m.hills
        func hill(baseY: CGFloat, amp: CGFloat, freq: Double, p0: Double, p1: Double) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h))
            let steps = 28
            for i in 0...steps {
                let x = w * CGFloat(i) / CGFloat(steps)
                let u = Double(i) / Double(steps)
                let y = baseY - amp * CGFloat(0.6 * sin(u * freq * 6.28 + p0) + 0.4 * sin(u * freq * 2.1 * 6.28 + p1))
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: w, y: h))
            p.closeSubpath()
            return p
        }
        let farBase = snowy ? TreeRGB(0xC9D6E6) : season == .autumn ? TreeRGB(0x6E7A4A) : TreeRGB(0x4E8A70)
        let nearBase = snowy ? TreeRGB(0xDCE6F0) : season == .autumn ? TreeRGB(0x5A6A33) : TreeRGB(0x2F6E4A)
        // Atmospheric perspective: distant hills take on the horizon colour.
        let far = TreeRGB.mix(farBase.lit(sky.ambient), sky.horizon, 0.45)
        let near = TreeRGB.mix(nearBase.lit(sky.ambient), sky.horizon, 0.18)
        ctx.fill(hill(baseY: horizonY, amp: h * 0.05, freq: 1.3, p0: ph[0], p1: ph[1]), with: .color(far.color))
        ctx.fill(hill(baseY: horizonY + h * 0.07, amp: h * 0.035, freq: 0.9, p0: ph[2], p1: ph[3]), with: .color(near.color))

        // Meadow / snowfield.
        let groundTop = (snowy ? TreeRGB(0xEEF4FB) : season == .autumn ? TreeRGB(0x4F6A2C) : TreeRGB(0x2C7040)).lit(sky.ambient)
        let groundBottom = (snowy ? TreeRGB(0xAFC0D4) : TreeRGB(0x123220)).lit(sky.ambient)
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: groundY + 6))
        ground.addQuadCurve(to: CGPoint(x: w, y: groundY + 6), control: CGPoint(x: w / 2, y: groundY - h * 0.06))
        ground.addLine(to: CGPoint(x: w, y: h))
        ground.addLine(to: CGPoint(x: 0, y: h))
        ground.closeSubpath()
        ctx.fill(ground, with: .linearGradient(Gradient(colors: [groundTop.color, groundBottom.color]),
                                               startPoint: CGPoint(x: 0, y: groundY - h * 0.03), endPoint: CGPoint(x: 0, y: h)))
        // Rim light along the ground's crest at golden hour.
        if sky.warmth > 0.05 {
            ctx.stroke(ground, with: .color(Color(.sRGB, red: 1, green: 0.8, blue: 0.45, opacity: 0.35 * sky.warmth)), lineWidth: 1.2)
        }
        // Fallen leaves gathered under the tree in autumn.
        if season == .autumn {
            for (k, g) in m.groundLeaves.enumerated() {
                let x = w * CGFloat(g.x), y = groundY + 3 + CGFloat(g.y) * 8
                let c = autumn[k % autumn.count].lit(sky.ambient).scaled(0.85)
                let tr = CGAffineTransform(translationX: x, y: y).rotated(by: g.phase).scaledBy(x: 9 * g.size, y: 6 * g.size)
                ctx.fill(leafPath.applying(tr), with: .color(c.color(0.9)))
            }
        }
    }

    private static func drawGrass(_ sky: TreeSky, m: WealthTreeModel, season: TreeSeason, t: Double, gust: Double,
                                  w: CGFloat, groundY: CGFloat, in ctx: inout GraphicsContext) {
        guard season != .winter else { return }
        let col = (season == .autumn ? TreeRGB(0x8A9A45) : TreeRGB(0x3E9A5E)).lit(sky.ambient)
        var blades = Path()
        for g in m.grass {
            let gx = CGFloat(g.x) * w
            let crest = abs(gx - w / 2) / (w / 2)
            let gy = groundY + 4 - (1 - crest * crest) * 6 + CGFloat(g.y) * 6
            let lean = g.phase + gust * 0.35 + sin(t * 2.4 + Double(gx) * 0.07) * 0.12
            blades.move(to: CGPoint(x: gx, y: gy))
            blades.addQuadCurve(to: CGPoint(x: gx + CGFloat(sin(lean)) * g.size, y: gy - g.size * CGFloat(cos(lean))),
                                control: CGPoint(x: gx, y: gy - g.size * 0.6))
        }
        ctx.stroke(blades, with: .color(col.color(0.9)), lineWidth: 1.2)
    }

    // MARK: Tree

    private static func drawBranches(_ sky: TreeSky, m: WealthTreeModel, season: TreeSeason, scratch: WealthTreeScratch,
                                     trunkLen: CGFloat, ldx: Double, in ctx: inout GraphicsContext) {
        let light = TreeRGB(0x8A5A34).lit(sky.ambient).color
        let mid = TreeRGB(0x5A3820).lit(sky.ambient).color
        let dark = TreeRGB(0x3B2414).lit(sky.ambient).color
        let knot = TreeRGB(0x4A2C17).lit(sky.ambient).color
        let snow = TreeRGB(0xF4F8FF).lit(sky.ambient).color
        let flip: CGFloat = ldx < 0 ? 1 : -1   // put the lit side of the bark towards the light
        for (i, n) in m.nodes.enumerated() {
            let w0 = scratch.width[i]
            let w1 = w0 * 0.66
            let a = scratch.angle[i]
            let nx = CGFloat(-sin(a)), ny = CGFloat(cos(a))
            let s = scratch.start[i], e = scratch.end[i]
            let bend = CGFloat(sin(n.phase)) * n.length * trunkLen * 0.08
            let mid0 = CGPoint(x: (s.x + e.x) / 2 + nx * bend, y: (s.y + e.y) / 2 + ny * bend)
            var p = Path()
            p.move(to: CGPoint(x: s.x + nx * w0 / 2, y: s.y + ny * w0 / 2))
            p.addQuadCurve(to: CGPoint(x: e.x + nx * w1 / 2, y: e.y + ny * w1 / 2),
                           control: CGPoint(x: mid0.x + nx * (w0 + w1) / 4, y: mid0.y + ny * (w0 + w1) / 4))
            p.addLine(to: CGPoint(x: e.x - nx * w1 / 2, y: e.y - ny * w1 / 2))
            p.addQuadCurve(to: CGPoint(x: s.x - nx * w0 / 2, y: s.y - ny * w0 / 2),
                           control: CGPoint(x: mid0.x - nx * (w0 + w1) / 4, y: mid0.y - ny * (w0 + w1) / 4))
            p.closeSubpath()
            ctx.fill(p, with: .linearGradient(Gradient(colors: [light, mid, dark]),
                                              startPoint: CGPoint(x: s.x + flip * nx * w0, y: s.y + flip * ny * w0),
                                              endPoint: CGPoint(x: s.x - flip * nx * w0, y: s.y - flip * ny * w0)))
            ctx.fill(Path(ellipseIn: CGRect(x: e.x - w1 / 2, y: e.y - w1 / 2, width: w1, height: w1)), with: .color(knot))

            // Snow settles along the top of level-ish branches.
            if season == .winter, abs(cos(a)) > 0.3 {
                let up: CGFloat = ny < 0 ? 1 : -1   // normal pointing upward on screen
                var line = Path()
                line.move(to: CGPoint(x: s.x + up * nx * w0 * 0.42, y: s.y + up * ny * w0 * 0.42))
                line.addQuadCurve(to: CGPoint(x: e.x + up * nx * w1 * 0.42, y: e.y + up * ny * w1 * 0.42),
                                  control: CGPoint(x: mid0.x + up * nx * (w0 + w1) * 0.3, y: mid0.y + up * ny * (w0 + w1) * 0.3))
                ctx.stroke(line, with: .color(snow), style: StrokeStyle(lineWidth: max(1.2, w1 * 0.55), lineCap: .round))
            }
        }
    }

    private static func drawFoliage(_ sky: TreeSky, m: WealthTreeModel, palette: [TreeRGB], season: TreeSeason, density: Double,
                                    t: Double, gust: Double, still: Bool, scratch: WealthTreeScratch, clusterR: Double,
                                    ldx: Double, ldy: Double, in ctx: inout GraphicsContext) {
        // Three tones per palette colour: shadow, base, sunlit.
        var tones: [[Color]] = []
        tones.reserveCapacity(palette.count)
        let rim = TreeRGB.mix(TreeRGB(1, 1, 1), sky.horizon, 0.5)
        for c in palette {
            let lit = c.lit(sky.ambient)
            tones.append([lit.scaled(0.62).color(0.95),
                          lit.color(0.94),
                          TreeRGB.mix(lit.scaled(1.18), rim, 0.12 + 0.25 * sky.warmth).color(0.95)])
        }
        let backTone = (season == .autumn ? TreeRGB(0x7A3A16) : season == .winter ? TreeRGB(0x0E4A32) : TreeRGB(0x0B6B3A))
            .lit(sky.ambient).color(0.9)

        let clusters = Double(m.leaves.count)
        let budget = 1500.0 * density
        let perCluster = Int(min(18, max(7, budget / max(1, clusters))))
        let backN = max(4, perCluster * 2 / 5), frontN = perCluster - backN + 3

        let golden = 2.399963
        for pass in 0..<2 {
            for i in m.leaves {
                let n = m.nodes[i]
                let e = scratch.end[i]
                let r = clusterR * Double(n.grow) * (pass == 0 ? 1.2 : 1)
                let count = pass == 0 ? backN : frontN
                // The whole cluster nods with the wind.
                let nod = still ? 0 : (gust * 1.4 + sin(t * 2.6 + n.phase) * 0.8)
                let cx = Double(e.x) + nod, cy = Double(e.y) + (still ? 0 : sin(t * 1.9 + n.phase) * 0.4)
                if pass == 1 {
                    // Sunlit sheen on the side facing the light.
                    let hc = CGPoint(x: cx + ldx * r * 0.35, y: cy + ldy * r * 0.35)
                    ctx.fill(Path(ellipseIn: CGRect(x: hc.x - r * 0.9, y: hc.y - r * 0.9, width: r * 1.8, height: r * 1.8)),
                             with: .radialGradient(Gradient(colors: [Color.white.opacity(0.05 + 0.08 * sky.warmth), .clear]),
                                                   center: hc, startRadius: 0, endRadius: r * 0.9))
                }
                for kk in 0..<count {
                    let k = count - 1 - kk   // outer leaves first, inner on top
                    let fr = (Double(k) + 0.5) / Double(count)
                    let rr = r * 0.62 * fr.squareRoot()
                    let th = Double(k) * golden + n.phase
                    let dx = cos(th), dy = sin(th)
                    let lx = cx + dx * rr * 1.05, ly = cy + dy * rr * 0.85
                    let flutter = still ? 0 : sin(t * (5.5 + Double(k % 4)) + n.phase + Double(k)) * 0.22 * (0.35 + gust)
                    let rot = th + 0.5 + flutter
                    let size = r * (pass == 0 ? 0.62 : 0.56)
                    let tr = CGAffineTransform(translationX: lx, y: ly).rotated(by: rot).scaledBy(x: size, y: size)
                    if pass == 0 {
                        ctx.fill(leafPath.applying(tr), with: .color(backTone))
                    } else {
                        let shade = (dx * ldx + dy * ldy) * fr + (1 - fr) * 0.25
                        let s = shade > 0.3 ? 2 : (shade > -0.3 ? 1 : 0)
                        ctx.fill(leafPath.applying(tr), with: .color(tones[(i + k) % tones.count][s]))
                    }
                }
                // Spring blossoms dot the canopy.
                if pass == 1, season == .spring, palette.count == spring.count {
                    for b in 0..<3 {
                        let th = Double(b) * 2.1 + n.phase * 1.7
                        let rr = r * (0.25 + 0.3 * Double(b) / 3)
                        let fx = cx + cos(th) * rr, fy = cy + sin(th) * rr * 0.8
                        let fs = r * 0.2
                        let petal = blossom[(i + b) % blossom.count].lit(sky.ambient)
                        let tr = CGAffineTransform(translationX: fx, y: fy).rotated(by: th).scaledBy(x: fs, y: fs)
                        ctx.fill(flowerPath.applying(tr), with: .color(petal.color(0.96)))
                        ctx.fill(Path(ellipseIn: CGRect(x: fx - fs * 0.22, y: fy - fs * 0.22, width: fs * 0.44, height: fs * 0.44)),
                                 with: .color(TreeRGB(0xFFD54F).lit(sky.ambient).color))
                    }
                }
            }
        }
    }

    private static func drawSnowCaps(_ sky: TreeSky, m: WealthTreeModel, scratch: WealthTreeScratch, clusterR: Double,
                                     in ctx: inout GraphicsContext) {
        let top = TreeRGB(0xFFFFFF).lit(sky.ambient), shade = TreeRGB(0xC8D6EA).lit(sky.ambient)
        for i in m.leaves {
            let n = m.nodes[i]
            let e = scratch.end[i]
            let r = clusterR * Double(n.grow)
            var cap = Path()
            for k in 0..<3 {
                let ox = (Double(k) - 1) * r * 0.32 + cos(n.phase) * r * 0.06
                let rw = r * (k == 1 ? 0.5 : 0.36)
                cap.addEllipse(in: CGRect(x: Double(e.x) + ox - rw, y: Double(e.y) - r * 0.5 - rw * 0.32 + abs(Double(k) - 1) * r * 0.08,
                                          width: rw * 2, height: rw * 0.68))
            }
            ctx.fill(cap, with: .linearGradient(Gradient(colors: [top.color(0.97), shade.color(0.9)]),
                                                startPoint: CGPoint(x: e.x, y: e.y - r * 0.7), endPoint: CGPoint(x: e.x, y: e.y - r * 0.3)))
        }
    }

    private static func drawLights(_ sky: TreeSky, m: WealthTreeModel, t: Double, still: Bool, scratch: WealthTreeScratch,
                                   clusterR: Double, in ctx: inout GraphicsContext) {
        let glowBoost = 0.45 + 0.55 * sky.night
        var bulb = 0
        for g in m.garlands {
            for j in 0..<(g.nodes.count - 1) {
                let a = scratch.end[g.nodes[j]], b = scratch.end[g.nodes[j + 1]]
                let dist = hypot(b.x - a.x, b.y - a.y)
                let ctrl = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + dist * 0.28 + CGFloat(clusterR) * 0.2)
                var wire = Path()
                wire.move(to: a)
                wire.addQuadCurve(to: b, control: ctrl)
                ctx.stroke(wire, with: .color(Color(.sRGB, red: 0.1, green: 0.12, blue: 0.1, opacity: 0.55)), lineWidth: 0.6)
                let count = max(2, Int(dist / 11))
                for s in 1...count {
                    let u = CGFloat(s) / CGFloat(count + 1)
                    let iu = 1 - u
                    let p = CGPoint(x: iu * iu * a.x + 2 * iu * u * ctrl.x + u * u * b.x,
                                    y: iu * iu * a.y + 2 * iu * u * ctrl.y + u * u * b.y)
                    let c = bulbs[bulb % bulbs.count]
                    let tw = still ? 1 : 0.55 + 0.45 * sin(t * 2.2 + Double(bulb) * 1.7)
                    let gr: CGFloat = 6
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - gr, y: p.y - gr, width: gr * 2, height: gr * 2)),
                             with: .radialGradient(Gradient(colors: [c.color(0.55 * tw * glowBoost), .clear]),
                                                   center: p, startRadius: 0, endRadius: gr))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.4, y: p.y - 1.1, width: 2.8, height: 2.8)),
                             with: .color(TreeRGB.mix(c, TreeRGB(1, 1, 1), 0.35 * tw).color))
                    bulb += 1
                }
            }
        }
    }

    // MARK: Coins

    private static func drawCoins(_ input: Input, m: WealthTreeModel, t: Double, rawT: Double, still: Bool, scratch: WealthTreeScratch,
                                  clusterR: Double, sky: TreeSky, in ctx: inout GraphicsContext) {
        // A coin pop always lands on the newest coin (or the first, if there were none yet).
        var popAge: Double?
        for ev in input.events where ev.kind == .coinPop {
            let age = still ? ev.duration : rawT - ev.start
            if age >= 0, age < ev.duration { popAge = age }
        }
        let hasPopped = input.events.contains { $0.kind == .coinPop }
        let shown = max(input.coins, hasPopped ? 1 : 0)
        let popRank = max(0, shown - 1)
        let coinR = 3.6 + 3.2 * input.growth
        let stemColor = TreeRGB(0x3B5E2B).lit(sky.ambient).color
        for i in m.leaves {
            let n = m.nodes[i]
            guard n.coinRank >= 0, n.coinRank < shown else { continue }
            var scale = 1.0
            var age: Double?
            if n.coinRank == popRank, let a = popAge {
                age = a
                // Springy grow-in from nothing.
                scale = a < 0 ? 0 : 1 - exp(-5.5 * a) * cos(11 * a)
                if scale <= 0.001 { continue }
            }
            let bob = still ? 0 : sin(t * 2.2 + n.phase) * 1.4
            let e = scratch.end[i]
            let anchor = CGPoint(x: e.x + CGFloat(cos(n.phase) * clusterR * 0.3), y: e.y + CGFloat(clusterR * 0.35))
            let c = CGPoint(x: anchor.x, y: anchor.y + CGFloat(coinR + 3 + bob))
            let cr = coinR * scale
            var stem = Path(); stem.move(to: anchor); stem.addLine(to: CGPoint(x: c.x, y: c.y - cr))
            ctx.stroke(stem, with: .color(stemColor), lineWidth: 0.8)
            let r = CGRect(x: c.x - cr, y: c.y - cr, width: cr * 2, height: cr * 2)
            let glowA = 0.25 + 0.25 * sky.night
            ctx.fill(Path(ellipseIn: r.insetBy(dx: -cr * 0.8, dy: -cr * 0.8)),
                     with: .radialGradient(Gradient(colors: [Color(.sRGB, red: 1, green: 0.84, blue: 0.25, opacity: glowA), .clear]),
                                           center: c, startRadius: 0, endRadius: cr * 1.8))
            // Spin a little as it pops in (horizontal squash = a coin turning to face you).
            var coinCtx = ctx
            if let a = age, a < 0.9 {
                let turn = abs(cos(a * 7)) * (1 - a / 0.9) + a / 0.9
                coinCtx.translateBy(x: c.x, y: c.y)
                coinCtx.scaleBy(x: max(0.15, turn), y: 1)
                coinCtx.translateBy(x: -c.x, y: -c.y)
            }
            coinCtx.fill(Path(ellipseIn: r), with: .radialGradient(
                Gradient(colors: [Color(.sRGB, red: 1, green: 0.95, blue: 0.69), Color(.sRGB, red: 1, green: 0.77, blue: 0),
                                  Color(.sRGB, red: 0.72, green: 0.53, blue: 0.04)]),
                center: CGPoint(x: c.x - cr * 0.35, y: c.y - cr * 0.35), startRadius: 0, endRadius: cr * 1.4))
            coinCtx.stroke(Path(ellipseIn: r.insetBy(dx: cr * 0.28, dy: cr * 0.28)),
                           with: .color(Color(.sRGB, red: 0.54, green: 0.38, blue: 0, opacity: 0.7)), lineWidth: 0.7)

            if let a = age { drawCoinShine(at: c, r: coinR, age: a, coinCtx: coinCtx, rect: r, in: &ctx) }
        }
    }

    /// The pop: an expanding ring, a rotating four-point glint and a highlight sweeping the face.
    private static func drawCoinShine(at c: CGPoint, r: Double, age a: Double, coinCtx: GraphicsContext, rect: CGRect,
                                      in ctx: inout GraphicsContext) {
        let gold = Color(.sRGB, red: 1, green: 0.84, blue: 0.25)
        if a < 0.7 {
            let k = a / 0.7
            let rr = r * (1.2 + 5 * k)
            var l = ctx
            l.opacity = (1 - k) * 0.9
            l.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(gold), lineWidth: 1.6 * (1 - k) + 0.4)
        }
        if a > 0.1, a < 1.3 {
            let k = (a - 0.1) / 1.2
            let s = sin(.pi * k)
            var l = ctx
            l.opacity = s
            l.translateBy(x: c.x + r * 0.5, y: c.y - r * 0.5)
            l.rotate(by: .radians(k * 1.6))
            l.fill(Sparkle.path(size: r * 4.5 * s + 2), with: .color(.white))
            l.fill(Sparkle.path(size: r * 2.2 * s + 1), with: .color(gold))
        }
        if a > 0.45, a < 1.15 {
            let k = (a - 0.45) / 0.7
            var l = coinCtx
            l.clip(to: Path(ellipseIn: rect))
            let x = rect.minX - r + CGFloat(k) * (rect.width + r * 2)
            var band = Path()
            band.move(to: CGPoint(x: x, y: rect.minY - 2))
            band.addLine(to: CGPoint(x: x + r * 0.7, y: rect.minY - 2))
            band.addLine(to: CGPoint(x: x - r * 0.3, y: rect.maxY + 2))
            band.addLine(to: CGPoint(x: x - r, y: rect.maxY + 2))
            band.closeSubpath()
            l.fill(band, with: .color(.white.opacity(0.75)))
        }
    }

    // MARK: Birds

    private static func drawBirds(_ count: Int, m: WealthTreeModel, sky: TreeSky, t: Double, still: Bool,
                                  scratch: WealthTreeScratch, trunkLen: CGFloat, in ctx: inout GraphicsContext) {
        // Robin, bluebird, goldfinch.
        let looks: [(body: TreeRGB, breast: TreeRGB, wing: TreeRGB)] = [
            (TreeRGB(0x6B4B3A), TreeRGB(0xF07A3C), TreeRGB(0x4A3328)),
            (TreeRGB(0x3D7BD9), TreeRGB(0xF2A65E), TreeRGB(0x2A579E)),
            (TreeRGB(0xFFD23F), TreeRGB(0xFFE57A), TreeRGB(0x2B2B2B))
        ]
        let asleep = sky.night > 0.6
        for b in 0..<min(count, m.perches.count) {
            let i = m.perches[b]
            let s = scratch.start[i], e = scratch.end[i]
            let u: CGFloat = 0.62
            let a = scratch.angle[i]
            let nx = CGFloat(-sin(a)), ny = CGFloat(cos(a))
            let up: CGFloat = ny < 0 ? 1 : -1
            let bw = scratch.width[i] * (1 - 0.34 * u)
            var p = CGPoint(x: s.x + (e.x - s.x) * u + up * nx * bw / 2, y: s.y + (e.y - s.y) * u + up * ny * bw / 2)
            let scale = max(0.75, min(1.25, trunkLen / 55))
            let phase = Double(b) * 2.3 + m.nodes[i].phase
            // Little hops and look-arounds.
            let hop = still || asleep ? 0 : pow(max(0, sin(t * 0.7 + phase)), 40) * 3
            p.y -= CGFloat(hop)
            let facingRight = still ? (e.x > s.x) : noise(t * 0.18 + phase * 3) > -0.1 ? (e.x > s.x) : !(e.x > s.x)
            let look = looks[b % looks.count]
            var l = ctx
            l.translateBy(x: p.x, y: p.y)
            l.scaleBy(x: (facingRight ? 1 : -1) * scale, y: scale)
            drawBird(body: look.body.lit(sky.ambient), breast: look.breast.lit(sky.ambient), wing: look.wing.lit(sky.ambient),
                     asleep: asleep, t: still ? 0 : t, phase: phase, in: &l)
        }
    }

    /// A small perched songbird facing +x, feet at the origin.
    private static func drawBird(body: TreeRGB, breast: TreeRGB, wing: TreeRGB, asleep: Bool, t: Double, phase: Double,
                                 in ctx: inout GraphicsContext) {
        let tailFlick = pow(max(0, sin(t * 1.3 + phase * 2)), 20) * 0.35
        // Tail
        var tail = Path()
        tail.move(to: CGPoint(x: -3.2, y: -4.2))
        tail.addLine(to: CGPoint(x: -9.5, y: -2.2 - 3 * tailFlick))
        tail.addLine(to: CGPoint(x: -9.0, y: -0.6 - 3 * tailFlick))
        tail.addLine(to: CGPoint(x: -2.6, y: -2.6))
        tail.closeSubpath()
        ctx.fill(tail, with: .color(wing.color))
        // Legs
        var legs = Path()
        legs.move(to: CGPoint(x: -0.6, y: -2.2)); legs.addLine(to: CGPoint(x: -0.9, y: 0))
        legs.move(to: CGPoint(x: 1.2, y: -2.2)); legs.addLine(to: CGPoint(x: 1.1, y: 0))
        ctx.stroke(legs, with: .color(Color(.sRGB, red: 0.25, green: 0.2, blue: 0.15)), lineWidth: 0.6)
        // Body + breast
        let bodyRect = asleep ? CGRect(x: -5, y: -9, width: 10.5, height: 8) : CGRect(x: -5, y: -8.2, width: 10, height: 6.8)
        ctx.fill(Path(ellipseIn: bodyRect), with: .color(body.color))
        ctx.fill(Path(ellipseIn: CGRect(x: bodyRect.minX + 4, y: bodyRect.minY + 2.2, width: 6, height: bodyRect.height - 2.4)),
                 with: .color(breast.color))
        // Wing
        var wingPath = Path()
        wingPath.addEllipse(in: CGRect(x: -4.6, y: bodyRect.minY + 1.4, width: 6.8, height: 3.8))
        ctx.fill(wingPath, with: .color(wing.color))
        if asleep {
            // Head tucked into the body; a closed eye.
            ctx.fill(Path(ellipseIn: CGRect(x: 1.6, y: bodyRect.minY - 1.6, width: 5.4, height: 5)), with: .color(body.color))
            var eye = Path(); eye.move(to: CGPoint(x: 4.0, y: bodyRect.minY + 0.8)); eye.addLine(to: CGPoint(x: 5.6, y: bodyRect.minY + 0.9))
            ctx.stroke(eye, with: .color(.black.opacity(0.7)), lineWidth: 0.6)
            return
        }
        let tilt = sin(t * 0.9 + phase) * 0.6
        let head = CGPoint(x: 4.2, y: -9.4 + CGFloat(tilt) * 0.3)
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2.9, y: head.y - 2.9, width: 5.8, height: 5.8)), with: .color(body.color))
        var beak = Path()
        beak.move(to: CGPoint(x: head.x + 2.4, y: head.y - 0.7))
        beak.addLine(to: CGPoint(x: head.x + 5.2, y: head.y + 0.1 + CGFloat(tilt) * 0.4))
        beak.addLine(to: CGPoint(x: head.x + 2.4, y: head.y + 0.9))
        beak.closeSubpath()
        ctx.fill(beak, with: .color(Color(.sRGB, red: 0.95, green: 0.7, blue: 0.25)))
        ctx.fill(Path(ellipseIn: CGRect(x: head.x + 0.4, y: head.y - 1.3, width: 1.5, height: 1.5)), with: .color(.black))
        ctx.fill(Path(ellipseIn: CGRect(x: head.x + 0.9, y: head.y - 1.1, width: 0.5, height: 0.5)), with: .color(.white))
    }

    // MARK: Weather & particles

    private static func drawWeather(_ sky: TreeSky, m: WealthTreeModel, season: TreeSeason, t: Double, w: CGFloat, h: CGFloat,
                                    groundY: CGFloat, palette: [TreeRGB], in ctx: inout GraphicsContext) {
        switch season {
        case .winter:
            let flake = TreeRGB(0xFFFFFF).lit(TreeRGB.mix(sky.ambient, TreeRGB(1, 1, 1), 0.4))
            for (k, f) in m.fallers.enumerated() {
                let near = k % 3 == 0
                let speed = (near ? 26 : 14) * f.speed
                let span = Double(h) + 12
                let y = (f.y * span + t * speed).truncatingRemainder(dividingBy: span) - 6
                let drift = t * (near ? 9 : 5) + sin(t * 0.8 * f.speed + f.phase) * (near ? 10 : 6)
                let x = (f.x * Double(w + 20) + drift).truncatingRemainder(dividingBy: Double(w + 20)) - 10
                let s = (near ? 3.2 : 1.8) * f.size
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(flake.color(near ? 0.9 : 0.6)))
            }
        case .spring:
            for (k, f) in m.fallers.prefix(9).enumerated() {
                let span = Double(h) + 20
                let y = (f.y * span + t * 11 * f.speed).truncatingRemainder(dividingBy: span) - 10
                let x = (f.x * Double(w + 30) + t * 7 + sin(t * 1.1 + f.phase) * 14).truncatingRemainder(dividingBy: Double(w + 30)) - 15
                let c = blossom[k % blossom.count].lit(sky.ambient)
                let tr = CGAffineTransform(translationX: x, y: y).rotated(by: t * 1.4 * f.spin + f.phase)
                    .scaledBy(x: 4.5 * f.size, y: 3 * f.size * abs(cos(t * 2 + f.phase)) + 0.6)
                ctx.fill(Path(ellipseIn: CGRect(x: -0.5, y: -0.5, width: 1, height: 1)).applying(tr), with: .color(c.color(0.9)))
            }
        case .autumn:
            for (k, f) in m.fallers.prefix(8).enumerated() {
                let span = Double(groundY) + 20
                let y = (f.y * span + t * 16 * f.speed).truncatingRemainder(dividingBy: span) - 10
                let x = (f.x * Double(w + 40) + t * 12 + sin(t * 1.3 + f.phase) * 18).truncatingRemainder(dividingBy: Double(w + 40)) - 20
                let c = palette[k % palette.count].lit(sky.ambient)
                let tr = CGAffineTransform(translationX: x, y: y).rotated(by: t * 2.2 * f.spin + f.phase + sin(t * 1.3 + f.phase))
                    .scaledBy(x: 9 * f.size, y: 7 * f.size * (0.25 + 0.75 * abs(cos(t * 2.4 + f.phase))))
                ctx.fill(leafPath.applying(tr), with: .color(c.color(0.95)))
            }
        case .summer:
            break
        }
        // Fireflies on warm nights.
        if season != .winter, sky.night > 0.3 {
            for f in m.fireflies {
                let x = Double(w) * f.x + sin(t * f.speed + f.phase) * 18 + sin(t * f.speed * 2.3 + f.spin) * 6
                let y = Double(h) * f.y + cos(t * f.speed * 0.8 + f.spin) * 10
                let pulse = pow(max(0, sin(t * 1.6 * f.speed + f.phase)), 3)
                let a = pulse * sky.night * (season == .summer ? 1 : 0.6)
                guard a > 0.02 else { continue }
                let r = 7 * f.size
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [Color(.sRGB, red: 0.85, green: 1, blue: 0.45, opacity: 0.6 * a), .clear]),
                                               center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                         with: .color(Color(.sRGB, red: 0.95, green: 1, blue: 0.7, opacity: a)))
            }
        }
    }

    /// One leaf letting go: a short tremble, then a swinging, tumbling fall that settles on the ground and fades.
    private static func drawFallingLeaf(_ ev: WealthTreeEvent, age: Double, m: WealthTreeModel, scratch: WealthTreeScratch,
                                        palette: [TreeRGB], sky: TreeSky, clusterR: Double, gust: Double, groundY: CGFloat,
                                        in ctx: inout GraphicsContext) {
        guard !m.leaves.isEmpty else { return }
        // Prefer an outer, lower cluster so the fall is visible.
        let src = m.leaves[(ev.id &* 7 &+ 3) % m.leaves.count]
        let e = scratch.end[src]
        let x0 = Double(e.x) + cos(Double(ev.id)) * clusterR * 0.4
        let y0 = Double(e.y) + clusterR * 0.25
        let hold = 0.45
        let size = clusterR * 0.62
        let c = palette[ev.id % palette.count].lit(sky.ambient)
        var x = x0, y = y0, rot = Double(ev.id) * 0.7, flip = 1.0, alpha = 1.0
        if age < hold {
            rot += sin(age * 60) * 0.18 * (age / hold)
        } else {
            // Falling: approaches terminal velocity, swinging like a pendulum while drifting downwind.
            let tf = age - hold
            let vt = 42.0, k = 1.6
            func fallY(_ s: Double) -> Double { y0 + vt * s - vt / k * (1 - exp(-k * s)) }
            func fallX(_ s: Double) -> Double { x0 + sin(s * 2.3) * 16 * min(1, s) + s * (6 + gust * 8) }
            var landT = tf
            if fallY(tf) >= Double(groundY) + 2 {
                var lo = 0.0, hi = tf
                for _ in 0..<12 { let mid = (lo + hi) / 2; if fallY(mid) < Double(groundY) + 2 { lo = mid } else { hi = mid } }
                landT = hi
            }
            y = min(fallY(landT), Double(groundY) + 2)
            x = fallX(landT)
            if landT < tf {
                rot += 1.2
                flip = 0.45
                alpha = max(0, 1 - (tf - landT) / 1.6)
            } else {
                rot += cos(landT * 2.3) * 0.9 + landT * 0.6
                flip = 0.2 + 0.8 * abs(cos(landT * 3.1))
            }
        }
        let tr = CGAffineTransform(translationX: x, y: y).rotated(by: rot).scaledBy(x: size, y: size * flip)
        ctx.fill(leafPath.applying(tr), with: .color(c.color(alpha)))
        var vein = Path()
        vein.move(to: CGPoint(x: -0.45, y: 0)); vein.addLine(to: CGPoint(x: 0.45, y: 0))
        ctx.stroke(vein.applying(tr), with: .color(c.scaled(0.7).color(alpha * 0.8)), lineWidth: 0.6)
    }
}

extension UUID {
    /// Stable 64-bit seed (unlike `hashValue`, which is randomised per process).
    var seed64: UInt64 { withUnsafeBytes(of: uuid) { $0.loadUnaligned(as: UInt64.self) } }
}
