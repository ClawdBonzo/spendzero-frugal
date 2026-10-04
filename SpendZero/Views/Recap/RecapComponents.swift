import SwiftUI

// Building blocks for the Monthly Recap story. Decorative pieces are hidden from VoiceOver
// (each card speaks one summary sentence) and settle to a static final frame under Reduce Motion.

// MARK: - Type + palette

enum RecapStyle {
    static let eyebrow = Color(hex: "7FD9A8")
    static let mutedText = Color(hex: "A9C4B6")
    static let ink = Color(hex: "3D2600")
    static let flameColors = [Color(hex: "FFF3B0"), Color(hex: "FFD740"), Color(hex: "FF9F1C"), Color(hex: "FF5E3A")]
    static let goldText = LinearGradient(colors: [Color(hex: "FFF6CC"), AppTheme.accentGold, Color(hex: "FFB300")],
                                         startPoint: .top, endPoint: .bottom)
}

/// Small tracked caps line above a card's headline.
struct RecapEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased(with: .current))
            .font(.app(size: 13, weight: .heavy, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(RecapStyle.eyebrow)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Per-card ambience: the living mesh tinted toward gold by `warmth`, with optional glow blooms.
struct RecapBackdrop: View {
    var warmth: Double
    var glow: [Color]? = nil
    var glowIntensity: Double = 0.18

    var body: some View {
        ZStack {
            LivingBackground(warmth: warmth)
            if let glow { GlowBackdrop(colors: glow, intensity: glowIntensity).ignoresSafeArea() }
            // Vignette keeps the progress bars and footer legible on any card.
            LinearGradient(colors: [.black.opacity(0.45), .clear, .clear, .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Coins

/// A minted day-coin: gold with the day number for a sealed day, a faint ring for a spent day,
/// and a dim dot for a day that wasn't logged. Canvas-drawn so it renders into share images.
struct RecapDayCoin: View {
    let day: Int
    let state: MonthRecap.DayState

    var body: some View {
        Canvas { ctx, size in
            let d = min(size.width, size.height)
            let r = d / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: d, height: d)
            switch state {
            case .sealed:
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: [Color(hex: "FFF1A8"), Color(hex: "FFC83D"), Color(hex: "D98E04"), Color(hex: "8A5A00")]),
                    center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.55))
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: r * 0.03, dy: r * 0.03)),
                           with: .color(Color(hex: "7A4E00").opacity(0.55)), lineWidth: max(0.8, r * 0.06))
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: r * 0.17, dy: r * 0.17)),
                           with: .color(Color(hex: "FFF6CC").opacity(0.75)), lineWidth: max(0.6, r * 0.05))
                ctx.draw(Text("\(day)").font(.system(size: r * 0.82, weight: .black, design: .rounded))
                            .foregroundColor(RecapStyle.ink.opacity(0.85)),
                         at: CGPoint(x: c.x, y: c.y + r * 0.02))
            case .spent:
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.05)))
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.75, dy: 0.75)), with: .color(.white.opacity(0.16)), lineWidth: 1.2)
                ctx.draw(Text("\(day)").font(.system(size: r * 0.72, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.32)),
                         at: c)
            case .unlogged:
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: r * 0.62, dy: r * 0.62)), with: .color(.white.opacity(0.14)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The month laid out as a calendar of coins (weeks as rows, starting on the locale's first weekday).
/// `revealed` coins are shown; the rest wait to pop in.
struct RecapCoinCalendar: View {
    let recap: MonthRecap
    var spacing: CGFloat = 8
    var revealed: Int = .max
    var animated: Bool = true

    var body: some View {
        let cal = Calendar.current
        let lead = (cal.component(.weekday, from: recap.month) - cal.firstWeekday + 7) % 7
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(0..<(lead + recap.days.count), id: \.self) { slot in
                if slot < lead {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                } else {
                    let i = slot - lead
                    let shown = i < revealed
                    RecapDayCoin(day: i + 1, state: recap.days[i])
                        .aspectRatio(1, contentMode: .fit)
                        .shadow(color: recap.days[i] == .sealed ? .black.opacity(0.35) : .clear, radius: 3, y: 2)
                        .scaleEffect(shown ? 1 : 0.2)
                        .rotation3DEffect(.degrees(shown || recap.days[i] != .sealed ? 0 : 160), axis: (x: 0, y: 1, z: 0))
                        .opacity(shown ? 1 : 0)
                        .animation(animated ? .spring(duration: 0.42, bounce: 0.45) : nil, value: shown)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Coin pour

/// Coins rain from the top and settle into a heap at the bottom; the heap's size follows the amount.
struct CoinPour: View {
    var count: Int
    var start: Date?
    var seed: UInt64 = 42

    private struct Coin {
        var x: CGFloat        // rest x, 0…1 of width
        var restLevel: Int    // stack height index in its column
        var column: Int
        var delay: Double
        var spin: Double
        var size: CGFloat
        var startX: CGFloat
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var coins: [Coin] {
        var rng = SeededGenerator(seed: seed)
        let columns = 11
        var heights = Array(repeating: 0, count: columns)
        return (0..<count).map { i in
            // Triangular distribution: the heap peaks in the middle.
            let u = Double.random(in: 0..<1, using: &rng) + Double.random(in: 0..<1, using: &rng)
            let col = min(columns - 1, Int(u / 2 * Double(columns)))
            let level = heights[col]
            heights[col] += 1
            let colX = (CGFloat(col) + 0.5) / CGFloat(columns)
            return Coin(x: colX + CGFloat(Double.random(in: -0.018...0.018, using: &rng)) + (level % 2 == 0 ? 0 : 0.012),
                        restLevel: level, column: col,
                        delay: Double(i) * 2.2 / Double(max(1, count)) + Double.random(in: 0...0.08, using: &rng),
                        spin: Double.random(in: 7...13, using: &rng),
                        size: CGFloat(Double.random(in: 0.92...1.08, using: &rng)),
                        startX: colX + CGFloat(Double.random(in: -0.12...0.12, using: &rng)))
        }
    }

    var body: some View {
        let coins = self.coins
        TimelineView(.animation(paused: reduceMotion || start == nil)) { tl in
            let t = reduceMotion ? 100 : start.map { tl.date.timeIntervalSince($0) } ?? -1
            Canvas { ctx, size in
                draw(coins, t: t, in: &ctx, size: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ coins: [Coin], t: Double, in ctx: inout GraphicsContext, size: CGSize) {
        guard t >= 0 else { return }
        let w = size.width, h = size.height
        let coinW = min(48, w / 9)
        let coinH = coinW * 0.36
        let step = coinH * 0.62
        let floor = h - coinH
        let gravity = 2400.0
        // Draw resting/lowest coins first so falling ones pass in front.
        for c in coins.sorted(by: { $0.restLevel < $1.restLevel }) {
            let local = t - c.delay
            guard local > 0 else { continue }
            let restY = floor - CGFloat(c.restLevel) * step
            let dropFrom = -coinW
            let fallTime = sqrt(2 * Double(restY - dropFrom) / gravity)
            let cw = coinW * c.size
            var y: CGFloat, x: CGFloat, squash: CGFloat
            if local < fallTime {
                let p = local / fallTime
                y = dropFrom + CGFloat(0.5 * gravity * local * local)
                x = (c.startX + (c.x - c.startX) * CGFloat(p)) * w
                squash = max(0.12, abs(CGFloat(cos(local * c.spin))))   // spinning edge-on and back
            } else {
                let after = local - fallTime
                let bounce = CGFloat(exp(-after * 9) * abs(sin(after * 22))) * coinH * 0.9
                y = restY - bounce
                x = c.x * w
                squash = 0.36
            }
            let bodyH = cw * squash
            let rect = CGRect(x: x - cw / 2, y: y - bodyH / 2, width: cw, height: bodyH)
            // Edge (thickness) then face.
            let edge = rect.offsetBy(dx: 0, dy: max(1.5, coinH * 0.22))
            ctx.fill(Path(ellipseIn: edge), with: .color(Color(hex: "8A5A00")))
            ctx.fill(Path(ellipseIn: rect), with: .linearGradient(
                Gradient(colors: [Color(hex: "FFF1A8"), Color(hex: "FFC83D"), Color(hex: "D98E04")]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: cw * 0.14, dy: bodyH * 0.16)),
                       with: .color(Color(hex: "FFF6CC").opacity(0.7)), lineWidth: 1)
        }
    }
}

// MARK: - Flame

/// A layered, flickering flame with embers drifting up. Static under Reduce Motion.
struct RecapFlame: View {
    var lit: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || !lit)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            let flick = 1 + 0.035 * sin(t * 13) + 0.025 * sin(t * 7.3 + 1)
            let sway = 2.5 * sin(t * 3.1)
            ZStack {
                Canvas { ctx, size in drawEmbers(t: t, in: &ctx, size: size) }
                Image(systemName: "flame.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(LinearGradient(colors: [RecapStyle.flameColors[1], RecapStyle.flameColors[2], RecapStyle.flameColors[3]],
                                                    startPoint: .top, endPoint: .bottom))
                    .scaleEffect(x: 1, y: flick, anchor: .bottom)
                    .rotationEffect(.degrees(sway), anchor: .bottom)
                    .shadow(color: RecapStyle.flameColors[2].opacity(0.8), radius: 24)
                    .padding(.horizontal, 26)
                Image(systemName: "flame.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(LinearGradient(colors: [.white, RecapStyle.flameColors[0], RecapStyle.flameColors[1]],
                                                    startPoint: .top, endPoint: .bottom))
                    .scaleEffect(x: 0.5, y: 0.5 * (2 - flick), anchor: .bottom)
                    .rotationEffect(.degrees(-sway * 1.4), anchor: .bottom)
                    .padding(.horizontal, 26)
                    .blendMode(.plusLighter)
            }
        }
        .scaleEffect(lit ? 1 : 0.2, anchor: .bottom)
        .opacity(lit ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func drawEmbers(t: Double, in ctx: inout GraphicsContext, size: CGSize) {
        guard !reduceMotion else { return }
        for i in 0..<16 {
            let life = 1.8 + Double(i % 5) * 0.25
            let phase = (t / life + Double(i) * 0.61803).truncatingRemainder(dividingBy: 1)
            let x = size.width * (0.5 + 0.28 * sin(Double(i) * 2.4) + 0.06 * sin(t * 2 + Double(i)))
            let y = size.height * (0.82 - phase * 0.95)
            let r = 2.2 * (1 - phase) + 0.6
            ctx.opacity = (1 - phase) * 0.9
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(i % 3 == 0 ? RecapStyle.flameColors[0] : RecapStyle.flameColors[2]))
        }
    }
}

// MARK: - Streak strip

/// The month as thin bars; the best run lights up gold as `fill` goes 0→1.
struct StreakStrip: View {
    let recap: MonthRecap
    var fill: Double

    var body: some View {
        let range = recap.bestStreakRange
        HStack(spacing: 3) {
            ForEach(Array(recap.days.enumerated()), id: \.offset) { i, s in
                let inRun = range?.contains(i) ?? false
                let lit: Bool = {
                    guard let range, inRun else { return false }
                    let k = Double(i - range.lowerBound + 1) / Double(range.count)
                    return k <= fill + 0.0001
                }()
                Capsule()
                    .fill(lit ? AnyShapeStyle(LinearGradient(colors: [RecapStyle.flameColors[1], RecapStyle.flameColors[2]],
                                                             startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(s == .sealed ? AppTheme.primaryGreen.opacity(0.28) : .white.opacity(0.08)))
                    .frame(height: lit ? 30 : 22)
                    .shadow(color: lit ? RecapStyle.flameColors[2].opacity(0.6) : .clear, radius: 5)
            }
        }
        .frame(height: 30)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: fill)
        .accessibilityHidden(true)
    }
}

// MARK: - Beaten urge medallion

/// A category disc that gets struck through — the urge, beaten.
struct BeatenUrgeBadge: View {
    let entry: MonthRecap.CategoryCount
    var shown: Bool
    var struck: Bool

    var body: some View {
        let tint = Color(hex: entry.category.color)
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(tint.opacity(0.16))
                Circle().stroke(struck ? AppTheme.primaryGreen : tint.opacity(0.6), lineWidth: 2.5)
                Image(systemName: entry.category.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(struck ? .white.opacity(0.55) : .white)
                SlashLine()
                    .trim(from: 0, to: struck ? 1 : 0)
                    .stroke(AppTheme.primaryGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .shadow(color: AppTheme.primaryGreen.opacity(0.8), radius: 6)
                    .padding(14)
            }
            .frame(width: 74, height: 74)
            .overlay(alignment: .topTrailing) {
                Text(verbatim: "×\(entry.count)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.accentGold))
                    .offset(x: 6, y: -4)
                    .scaleEffect(struck ? 1 : 0.01)
            }
            Text(entry.category.localizedName)
                .font(.app(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(RecapStyle.mutedText)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .frame(width: 84)
        }
        .scaleEffect(shown ? 1 : 0.3)
        .opacity(shown ? 1 : 0)
        .accessibilityHidden(true)
    }

    private struct SlashLine: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            return p
        }
    }
}

// MARK: - Growing tree

/// WealthTreeCanvas whose growth interpolates smoothly inside `withAnimation`.
struct GrowingWealthTree: View, Animatable {
    var growth: Double
    let seed: UInt64
    var vitality: Double = 0.95
    var coins: Int = 10

    var animatableData: Double {
        get { growth }
        set { growth = newValue }
    }

    var body: some View {
        WealthTreeCanvas(seed: seed, growth: growth, vitality: vitality, coins: coins)
    }
}

// MARK: - Buttons

struct RecapPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: 16, weight: .black, design: .rounded))
            .foregroundColor(Color(hex: "1A1200"))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 18).fill(AppTheme.accentGold))
            .goldSheen(0.8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct RecapSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size: 16, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.22), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
