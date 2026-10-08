import SwiftUI

/// The last onboarding beat before the paywall: the user's own answers turned into a
/// 12-month picture. Beats: header (0s) → total + card (0.4s) → the line draws itself
/// (0.9s, 2.1s long) with a coin minted at each quarter, the total rolling up with each
/// coin → the year-one coin lands with a seal haptic and a clink.
struct SavingsForecastView: View {
    let name: String
    let forecast: SavingsForecast
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHeader = false
    @State private var showTotal = false
    @State private var showCard = false
    @State private var progress: CGFloat = 0
    @State private var coinsShown = 0
    @State private var displayed: Double = 0
    @State private var showRows = false
    @State private var showCTA = false
    @State private var showMath = false

    private static let drawDuration = 2.1

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            GlowBackdrop(colors: [AppTheme.primaryGreen, Color(hex: "00BFA5"), AppTheme.accentGold], intensity: 0.09)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        totalBlock
                        chartCard
                        rows
                        if showMath { mathCard.transition(.move(edge: .top).combined(with: .opacity)) }
                    }
                    .padding(.horizontal, AppTheme.paddingLarge)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)

                VStack(spacing: 12) {
                    PrimaryButton(title: "Start keeping it", icon: "arrow.right", action: onContinue)
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showMath.toggle() }
                    } label: {
                        Text("How the estimate works")
                            .font(.app(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .accessibilityHint(Text(verbatim: equation))
                }
                .padding(.horizontal, AppTheme.paddingLarge)
                .padding(.bottom, 20)
                .opacity(showCTA ? 1 : 0)
                .offset(y: showCTA ? 0 : 24)
            }
        }
        .task { await run() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your plan is ready")
                .textCase(.uppercase)
                .font(.app(size: 12, weight: .heavy, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(AppTheme.primaryGreen)
            Text(title)
                .font(.app(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .opacity(showHeader ? 1 : 0)
        .offset(y: showHeader ? 0 : 14)
    }

    private var title: String {
        name.isEmpty
            ? String(localized: "Here's what you could keep")
            : String(localized: "Here's what you could keep, \(name)")
    }

    private var byDate: String {
        String(localized: "by \(forecast.endDate.formatted(.dateTime.month(.wide).year()))")
    }

    private var totalBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayed.currencyFormatted)
                .font(.app(size: 64, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LinearGradient(colors: [Color(hex: "FFF1A8"), AppTheme.accentGold, Color(hex: "FFB300")],
                                                startPoint: .top, endPoint: .bottom))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: displayed))
                .goldSheen(0.9)
                .shadow(color: AppTheme.accentGold.opacity(0.35), radius: 18, y: 4)
            Text(byDate)
                .font(.app(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "A9B4C2"))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(forecast.total.currencyFormatted) \(byDate)"))
        .opacity(showTotal ? 1 : 0)
        .scaleEffect(showTotal ? 1 : 0.92, anchor: .leading)
    }

    private var chartCard: some View {
        ForecastChart(forecast: forecast, progress: progress, coinsShown: coinsShown)
            .frame(height: 214)
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.01)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Savings forecast"))
            .accessibilityValue(Text("Grows to \(forecast.total.currencyFormatted) over the next 12 months"))
            .opacity(showCard ? 1 : 0)
            .offset(y: showCard ? 0 : 20)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ExplainRow(badge: "\(forecast.goalDaysPerMonth)", tint: AppTheme.primaryGreen,
                       text: "no-spend days a month, based on your goal")
            ExplainRow(badge: forecast.dailyExtras.currencyFormatted, tint: AppTheme.accentGold,
                       text: "you usually spend on extras each day")
            Text("An estimate from your answers, not a guarantee.")
                .font(.app(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "6F7B8B"))
                .padding(.top, 2)
        }
        .opacity(showRows ? 1 : 0)
        .offset(y: showRows ? 0 : 12)
    }

    private var equation: String {
        String(localized: "\(forecast.goalDaysPerMonth) no-spend days × \(forecast.dailyExtras.currencyFormatted) a day × 12 months = \(forecast.total.currencyFormatted)")
    }

    private var mathCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "function")
                .font(.app(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.accentGold)
            Text(verbatim: equation)
                .font(.app(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.cardBackground))
    }

    // MARK: - Choreography

    private func run() async {
        if reduceMotion {
            showHeader = true; showTotal = true; showCard = true; showRows = true; showCTA = true
            progress = 1; coinsShown = SavingsForecast.milestones.count; displayed = forecast.total
            return
        }
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) { showHeader = true }
        guard await pause(0.25) else { return }
        withAnimation(.spring(duration: 0.6, bounce: 0.25)) { showTotal = true }
        guard await pause(0.15) else { return }
        withAnimation(.spring(duration: 0.7, bounce: 0.15)) { showCard = true }
        guard await pause(0.45) else { return }

        let d = Self.drawDuration
        withAnimation(.timingCurve(.easeInOut, duration: d)) { progress = 1 }

        var elapsed = 0.0
        let milestones = SavingsForecast.milestones
        for (i, month) in milestones.enumerated() {
            let at = Self.time(reaching: Double(month) / Double(SavingsForecast.months)) * d
            guard await pause(at - elapsed) else { return }
            elapsed = at
            let isLast = i == milestones.count - 1
            withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) { coinsShown = i + 1 }
            withAnimation(.snappy(duration: isLast ? 0.7 : 0.45)) { displayed = forecast.cumulative(afterMonth: month) }
            if isLast {
                CoinHaptics.seal()
                SoundEffects.play(.clink, volume: 0.5)
            } else {
                CoinHaptics.tick()
            }
            if i == 1 { withAnimation(.spring(duration: 0.6, bounce: 0.2)) { showRows = true } }
        }
        guard await pause(0.25) else { return }
        withAnimation(.spring(duration: 0.6, bounce: 0.25)) { showCTA = true }
    }

    /// Returns false when the view went away (the task was cancelled).
    private func pause(_ seconds: Double) async -> Bool {
        guard seconds > 0 else { return !Task.isCancelled }
        return (try? await Task.sleep(for: .seconds(seconds))) != nil
    }

    /// The normalised time at which the ease-in-out draw reaches `fraction` of the way across,
    /// so each coin pops exactly as the line's head passes it.
    private static func time(reaching fraction: Double) -> Double {
        var lo = 0.0, hi = 1.0
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if UnitCurve.easeInOut.value(at: mid) < fraction { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }
}

// MARK: - Explanation row

private struct ExplainRow: View {
    let badge: String
    let tint: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: badge)
                .font(.app(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .frame(minWidth: 44, minHeight: 28)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.14)))
            Text(text)
                .font(.app(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "E8EEF0"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chart

/// The forecast line, area and coins. Static scaffolding (grid, axis labels) is a single Canvas
/// drawn once; only the line trim, area mask, head and coins animate.
struct ForecastChart: View {
    let forecast: SavingsForecast
    var progress: CGFloat
    var coinsShown: Int

    var body: some View {
        GeometryReader { geo in
            let plot = PlotGeometry(size: geo.size, forecast: forecast)
            let line = plot.linePath
            let first = plot.point(0), last = plot.point(SavingsForecast.months)

            ZStack(alignment: .topLeading) {
                ChartScaffold(forecast: forecast, plot: plot)

                // Area under the line, revealed left → right in step with the stroke.
                plot.areaPath
                    .fill(LinearGradient(colors: [AppTheme.primaryGreen.opacity(0.36), AppTheme.primaryGreen.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: first.x + (last.x - first.x) * progress)
                    }

                // Soft bloom under the stroke.
                line.trim(from: 0, to: progress)
                    .stroke(AppTheme.primaryGreen.opacity(0.55), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                    .blur(radius: 7)

                line.trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [AppTheme.primaryGreen, Color(hex: "7CF29B"), AppTheme.accentGold],
                                           startPoint: UnitPoint(x: first.x / geo.size.width, y: 0),
                                           endPoint: UnitPoint(x: last.x / geo.size.width, y: 0)),
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))

                // The pen: a bright head that rides the line while it draws.
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .shadow(color: AppTheme.primaryGreen, radius: 6)
                    .shadow(color: AppTheme.primaryGreen.opacity(0.8), radius: 12)
                    .position(x: first.x + (last.x - first.x) * progress,
                              y: first.y + (last.y - first.y) * progress)
                    .opacity(progress > 0.01 && progress < 0.995 ? 1 : 0)

                ForEach(Array(SavingsForecast.milestones.enumerated()), id: \.offset) { index, month in
                    let isLast = month == SavingsForecast.months
                    ChartCoin(size: isLast ? 24 : 15, isFinal: isLast, shown: coinsShown > index)
                        .position(plot.point(month))
                }

                YearOnePill()
                    .position(x: last.x - 58, y: max(12, last.y - 14))
                    .opacity(coinsShown >= SavingsForecast.milestones.count ? 1 : 0)
                    .scaleEffect(coinsShown >= SavingsForecast.milestones.count ? 1 : 0.6,
                                 anchor: .trailing)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6).delay(0.12), value: coinsShown)
            }
        }
    }
}

/// Maps months and money to points inside the chart.
struct PlotGeometry {
    let size: CGSize
    let forecast: SavingsForecast

    var left: CGFloat { 10 }
    var right: CGFloat { size.width - 16 }
    var top: CGFloat { 34 }
    var bottom: CGFloat { size.height - 26 }

    func x(_ month: Int) -> CGFloat { left + (right - left) * CGFloat(month) / CGFloat(SavingsForecast.months) }
    func y(_ amount: Double) -> CGFloat {
        let scale = max(forecast.total, 1)
        return bottom - (bottom - top) * CGFloat(amount / scale)
    }
    func point(_ month: Int) -> CGPoint { CGPoint(x: x(month), y: y(forecast.cumulative(afterMonth: month))) }

    var linePath: Path {
        Path { p in
            p.move(to: point(0))
            for m in 1...SavingsForecast.months { p.addLine(to: point(m)) }
        }
    }

    var areaPath: Path {
        var p = linePath
        p.addLine(to: CGPoint(x: x(SavingsForecast.months), y: bottom))
        p.addLine(to: CGPoint(x: x(0), y: bottom))
        p.closeSubpath()
        return p
    }

    /// Round grid values (1, 2, 2.5, 5 × 10ⁿ), roughly three steps up to the total.
    var gridValues: [Double] {
        let total = forecast.total
        guard total > 0 else { return [] }
        let raw = total / 3
        let mag = pow(10, floor(log10(raw)))
        let step = [5, 2.5, 2, 1].map { $0 * mag }.first(where: { $0 <= raw }) ?? mag
        return stride(from: step, through: total * 0.94, by: step).map { $0 }
    }
}

private struct ChartScaffold: View {
    let forecast: SavingsForecast
    let plot: PlotGeometry

    var body: some View {
        Canvas { ctx, size in
            // Baseline + grid with their value labels sitting on the line.
            var base = Path()
            base.move(to: CGPoint(x: 0, y: plot.bottom))
            base.addLine(to: CGPoint(x: size.width, y: plot.bottom))
            ctx.stroke(base, with: .color(Color(hex: "232C3A")), lineWidth: 1)

            for value in plot.gridValues {
                let y = plot.y(value)
                var g = Path()
                g.move(to: CGPoint(x: 0, y: y))
                g.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(g, with: .color(Color(hex: "1B2330")), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                let label = ctx.resolve(Text(verbatim: value.compactCurrency)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "5C6878")))
                ctx.draw(label, at: CGPoint(x: 0, y: y - 4), anchor: .bottomLeading)
            }

            // Month labels for the next 12 months; quarter milestones read brighter.
            let spacing = plot.x(1) - plot.x(0)
            let abbreviated = (1...SavingsForecast.months).map {
                forecast.date(afterMonths: $0).formatted(.dateTime.month(.abbreviated))
            }
            let resolved = abbreviated.enumerated().map { i, s in
                let isMilestone = SavingsForecast.milestones.contains(i + 1)
                return ctx.resolve(Text(verbatim: s)
                    .font(.system(size: 10, weight: isMilestone ? .heavy : .semibold, design: .rounded))
                    .foregroundColor(isMilestone ? Color(hex: "A9B4C2") : Color(hex: "5C6878")))
            }
            let fits = resolved.allSatisfy { $0.measure(in: size).width < spacing - 2 }
            for m in 1...SavingsForecast.months {
                let isMilestone = SavingsForecast.milestones.contains(m)
                let text: GraphicsContext.ResolvedText
                if fits {
                    text = resolved[m - 1]
                } else {
                    text = ctx.resolve(Text(verbatim: forecast.date(afterMonths: m).formatted(.dateTime.month(.narrow)))
                        .font(.system(size: 10, weight: isMilestone ? .heavy : .semibold, design: .rounded))
                        .foregroundColor(isMilestone ? Color(hex: "A9B4C2") : Color(hex: "5C6878")))
                }
                ctx.draw(text, at: CGPoint(x: plot.x(m), y: plot.bottom + 9), anchor: .top)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ChartCoin: View {
    let size: CGFloat
    let isFinal: Bool
    let shown: Bool

    @State private var ring = false

    var body: some View {
        ZStack {
            if isFinal {
                Circle()
                    .stroke(AppTheme.accentGold.opacity(ring ? 0 : 0.8), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(ring ? 2.6 : 1)
                Circle()
                    .fill(RadialGradient(colors: [AppTheme.accentGold.opacity(0.45), .clear],
                                         center: .center, startRadius: 0, endRadius: size))
                    .frame(width: size * 2.4, height: size * 2.4)
            }
            Circle()
                .fill(RadialGradient(colors: [Color(hex: "FFF1A8"), Color(hex: "FFC83D"), Color(hex: "B07608")],
                                     center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
                .overlay(Circle().inset(by: size * 0.16).stroke(Color(hex: "FFF3B0").opacity(0.7), lineWidth: 0.8))
                .overlay(Circle().stroke(isFinal ? Color(hex: "FFE27A") : Color(hex: "8A5A00").opacity(0.6),
                                         lineWidth: isFinal ? 2 : 0.8))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        }
        .scaleEffect(shown ? 1 : 0.01)
        .opacity(shown ? 1 : 0)
        .onChange(of: shown) { _, now in
            guard now, isFinal else { return }
            withAnimation(.easeOut(duration: 0.9)) { ring = true }
        }
    }
}

private struct YearOnePill: View {
    var body: some View {
        Text("Year one")
            .font(.app(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(AppTheme.accentGold)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppTheme.background))
            .overlay(Capsule().strokeBorder(AppTheme.accentGold.opacity(0.5), lineWidth: 1))
            .fixedSize()
    }
}

#Preview {
    SavingsForecastView(name: "Alex",
                        forecast: SavingsForecast(level: .minimal, challengeDays: 14),
                        onContinue: {})
}
