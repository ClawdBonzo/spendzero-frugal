import SwiftUI

/// The Mint Calendar: a whole year at a glance, one coin per day. Sealed no-spend days are minted
/// gold (brighter the more was kept), missed days are dull, days ahead are empty outlines.
struct MintCalendarView: View {
    let ledger: DayLedger
    @Binding var year: Int
    /// The day whose coin is the zoom-transition source (set just before pushing the detail).
    let zoomSource: Date?
    let zoomNamespace: Namespace.ID
    let onSelect: (Date) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var statsShown = false

    private var mint: MintYear { MintYear(year: year, ledger: ledger) }
    private var currentYear: Int { ledger.calendar.component(.year, from: ledger.today) }

    var body: some View {
        let mint = mint
        VStack(alignment: .leading, spacing: 16) {
            header
            stats(mint)
            MintYearGrid(mint: mint, zoomSource: zoomSource, zoomNamespace: zoomNamespace, onSelect: onSelect)
            bestMonthCallout(mint)
        }
        .onAppear {
            if reduceMotion { statsShown = true; return }
            withAnimation(.snappy(duration: 0.7).delay(0.15)) { statsShown = true }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mint Calendar \(String(year))")
                    .font(.app(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .contentTransition(.numericText(value: Double(year)))
                Text("Every gold coin is a day you didn't spend.")
                    .font(.app(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 8)
            if ledger.years.count > 1 {
                HStack(spacing: 4) {
                    yearButton(-1, icon: "chevron.left", label: Text("Previous year"))
                    yearButton(1, icon: "chevron.right", label: Text("Next year"))
                }
            }
        }
    }

    private func yearButton(_ delta: Int, icon: String, label: Text) -> some View {
        let target = year + delta
        let enabled = ledger.years.contains(target)
        return Button {
            CoinHaptics.tick()
            withAnimation(.snappy) { year = target }
        } label: {
            Image(systemName: icon)
                .font(.app(size: 15, weight: .bold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(AppTheme.cardBackground))
                .foregroundStyle(enabled ? AppTheme.textPrimary : AppTheme.textTertiary.opacity(0.5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: Stats

    private func stats(_ mint: MintYear) -> some View {
        HStack(spacing: 10) {
            statTile(value: Text("\(statsShown ? mint.sealedCount : 0)")
                        .contentTransition(.numericText(value: Double(statsShown ? mint.sealedCount : 0))),
                     color: AppTheme.accentGold, title: Text("days sealed"),
                     a11y: Text("\(mint.sealedCount) days sealed"))
            statTile(value: Text("\(statsShown ? mint.longestStreak : 0)")
                        .contentTransition(.numericText(value: Double(statsShown ? mint.longestStreak : 0))),
                     color: AppTheme.textPrimary, title: Text("longest streak"),
                     a11y: Text("Longest streak: \(mint.longestStreak) days"))
            statTile(value: Text((statsShown ? mint.keptTotal : 0).currencyFormatted)
                        .contentTransition(.numericText(value: statsShown ? mint.keptTotal : 0)),
                     color: AppTheme.primaryGreen, title: Text("kept this year"),
                     a11y: Text("Kept this year: \(mint.keptTotal.currencyFormatted)"))
        }
        .sensoryFeedback(.increase, trigger: statsShown)
    }

    private func statTile(value: some View, color: Color, title: Text, a11y: Text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            value
                .font(.app(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            title
                .font(.app(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.cardBackground))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }

    // MARK: Best month

    @ViewBuilder
    private func bestMonthCallout(_ mint: MintYear) -> some View {
        HStack(spacing: 12) {
            MintCoin(size: 40, level: 1, glow: false)
                .goldSheen()
            VStack(alignment: .leading, spacing: 2) {
                if let best = mint.bestMonth {
                    let name = best.start.formatted(.dateTime.month(.wide))
                    let isCurrent = year == currentYear
                        && ledger.calendar.isDate(best.start, equalTo: ledger.today, toGranularity: .month)
                    Group {
                        if isCurrent {
                            Text("\(name) is your best month yet")
                        } else {
                            Text("\(name) was your best month")
                        }
                    }
                    .font(.app(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    Text(bestMonthDetail(best, isCurrent: isCurrent))
                        .font(.app(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Your first coin is waiting")
                        .font(.app(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Seal a no-spend day to mint it.")
                        .font(.app(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.cardBackground))
        .accessibilityElement(children: .combine)
    }

    private func bestMonthDetail(_ best: MintYear.Month, isCurrent: Bool) -> String {
        let sealed = best.sealedCount == 1
            ? String(localized: "1 day sealed.")
            : String(localized: "\(best.sealedCount) days sealed.")
        if isCurrent { return sealed + " " + String(localized: "Keep it going.") }
        guard year == currentYear else { return sealed }
        let thisMonth = ledger.today.formatted(.dateTime.month(.wide))
        return sealed + " " + String(localized: "Can \(thisMonth) beat it?")
    }
}

// MARK: - Grid

/// The 12 × 31 coin grid, drawn in a single Canvas (cheap at 120 Hz) with a diagonal ripple on
/// appear. Tapping a coin opens that day; VoiceOver gets one element per day, grouped by month.
struct MintYearGrid: View {
    let mint: MintYear
    let zoomSource: Date?
    let zoomNamespace: Namespace.ID
    let onSelect: (Date) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleStart: Date?
    @State private var rippleDone = false
    @State private var width: CGFloat = 340

    private static let labelWidth: CGFloat = 28
    private static let rowGap: CGFloat = 6
    /// Per-step delay of the diagonal ripple; (month + day) steps, ~0.6 s overall.
    private static let rippleStep = 0.0085
    private static let popDuration = 0.26

    private var cell: CGFloat { max(6, (width - Self.labelWidth) / 31) }
    private var rowHeight: CGFloat { cell + Self.rowGap }
    private var dot: CGFloat { cell * 0.8 }

    var body: some View {
        VStack(spacing: 10) {
            grid
                .frame(height: rowHeight * 12 - Self.rowGap)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            legend
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppTheme.cardBackground))
        .onAppear(perform: startRipple)
        .onChange(of: mint.year) { _, _ in startRipple() }
    }

    private var grid: some View {
        TimelineView(.animation(minimumInterval: nil, paused: rippleDone)) { timeline in
            let elapsed = rippleDone ? 10 : rippleStart.map { timeline.date.timeIntervalSince($0) } ?? 0
            Canvas { ctx, _ in draw(in: &ctx, elapsed: elapsed) }
        }
        .goldSheen(0.9)
        .contentShape(Rectangle())
        .gesture(SpatialTapGesture().onEnded { tap in
            if let day = day(at: tap.location), day.state != .future { open(day) }
        })
        .overlay(alignment: .topLeading) { transitionSource }
        .overlay { accessibilityRows }
    }

    // MARK: Drawing

    private func position(month: Int, day: Int) -> CGPoint {
        CGPoint(x: Self.labelWidth + cell * (CGFloat(day) + 0.5), y: rowHeight * CGFloat(month) + cell / 2)
    }

    private func draw(in ctx: inout GraphicsContext, elapsed: Double) {
        let symbols = Calendar.current.shortStandaloneMonthSymbols
        for month in mint.months {
            let label = ctx.resolve(Text(symbols[month.index % symbols.count])
                .font(.system(size: min(11, cell * 1.1), weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.textSecondary))
            ctx.draw(label, at: CGPoint(x: 0, y: rowHeight * CGFloat(month.index) + cell / 2), anchor: .leading)

            for day in month.days {
                let p = position(month: day.month, day: day.day)
                let delay = Double(day.month + day.day) * Self.rippleStep
                let t = max(0, min(1, (elapsed - delay) / Self.popDuration))
                guard t > 0 else { continue }
                let scale = Self.easeOutBack(t)
                var layer = ctx
                layer.opacity = min(1, t * 2.5)
                drawCoin(day, at: p, scale: scale, in: &layer)
            }
        }
    }

    private func drawCoin(_ day: MintYear.Day, at p: CGPoint, scale: CGFloat, in ctx: inout GraphicsContext) {
        let r = dot / 2 * scale
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        switch day.state {
        case .sealed(let level, let glow):
            if glow {
                let g = r * 2.3
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                         with: .radialGradient(Gradient(colors: [MintPalette.glow.opacity(0.55), MintPalette.glow.opacity(0)]),
                                               center: p, startRadius: r * 0.5, endRadius: g))
            }
            let colors = MintPalette.levels[level]
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: colors), center: CGPoint(x: p.x - r * 0.35, y: p.y - r * 0.4),
                startRadius: 0, endRadius: r * 1.5))
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.3, dy: 0.3)),
                       with: .color(MintPalette.rim.opacity(0.35)), lineWidth: 0.6)
        case .missed:
            // Smaller and flat: reads as "empty" even without colour.
            let m = r * 0.78
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - m, y: p.y - m, width: m * 2, height: m * 2)),
                     with: .color(MintPalette.missed))
        case .today:
            ctx.fill(Path(ellipseIn: rect), with: .color(MintPalette.future))
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -1, dy: -1)), with: .color(AppTheme.primaryGreen), lineWidth: 1.5)
        case .future:
            ctx.fill(Path(ellipseIn: rect), with: .color(MintPalette.future))
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(MintPalette.missed), lineWidth: 1)
        case .dormant:
            let m = r * 0.5
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - m, y: p.y - m, width: m * 2, height: m * 2)),
                     with: .color(MintPalette.missed.opacity(0.6)))
        }
    }

    private static func easeOutBack(_ t: Double) -> CGFloat {
        let c1 = 1.9, c3 = c1 + 1
        return CGFloat(1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2))
    }

    private func startRipple() {
        guard !reduceMotion else { rippleDone = true; return }
        rippleDone = false
        rippleStart = .now
        let total = Double(11 + 30) * Self.rippleStep + Self.popDuration + 0.05
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(total))
            rippleDone = true
        }
    }

    // MARK: Hit testing + transition

    private func day(at point: CGPoint) -> MintYear.Day? {
        let row = Int(point.y / rowHeight)
        let col = Int(((point.x - Self.labelWidth) / cell).rounded(.down))
        guard mint.months.indices.contains(row), col >= 0 else { return nil }
        let days = mint.months[row].days
        return days.indices.contains(col) ? days[col] : nil
    }

    private func open(_ day: MintYear.Day) {
        if isSealedState(day.state) { CoinHaptics.seal() } else { CoinHaptics.tick() }
        onSelect(day.date)
    }

    /// A real coin sitting exactly on the tapped dot, so the zoom transition grows out of it.
    @ViewBuilder
    private var transitionSource: some View {
        if let source = zoomSource, let day = mint.months.flatMap(\.days).first(where: { $0.date == source }) {
            let p = position(month: day.month, day: day.day)
            Group {
                if case .sealed(let level, _) = day.state {
                    MintCoin(size: dot, level: level)
                } else {
                    Circle().fill(MintPalette.missed).frame(width: dot, height: dot)
                }
            }
            .matchedTransitionSource(id: source, in: zoomNamespace) { $0.clipShape(RoundedRectangle(cornerRadius: dot / 2)) }
            .offset(x: p.x - dot / 2, y: p.y - dot / 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: Accessibility

    private var accessibilityRows: some View {
        VStack(spacing: 0) {
            ForEach(mint.months) { month in
                Color.clear
                    .frame(height: rowHeight)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text(month.start, format: .dateTime.month(.wide)))
                    .accessibilityChildren {
                        HStack(spacing: 0) {
                            ForEach(month.days) { day in
                                Color.clear
                                    .accessibilityElement()
                                    .accessibilityLabel(Text(day.date, format: .dateTime.month(.wide).day()))
                                    .accessibilityValue(Self.describe(day))
                                    .accessibilityAddTraits(day.state == .future ? [] : .isButton)
                                    .accessibilityAction {
                                        if day.state != .future { onSelect(day.date) }
                                    }
                            }
                        }
                    }
            }
        }
        .padding(.leading, Self.labelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private static func describe(_ day: MintYear.Day) -> Text {
        switch day.state {
        case .sealed(_, let glow):
            let kept = Text("Sealed, \(day.kept.currencyFormatted) kept")
            return glow ? Text("\(kept), a top day") : kept
        case .missed: return Text("Not sealed")
        case .today: return Text("Today, not sealed yet")
        case .future: return Text("Ahead")
        case .dormant: return Text("Before you started")
        }
    }

    // MARK: Legend

    private var legend: some View {
        HStack(spacing: 5) {
            legendItem(shape: Circle().fill(MintPalette.missed).frame(width: 7, height: 7), text: Text("Missed"))
            legendItem(shape: Circle().fill(MintPalette.future).overlay(Circle().strokeBorder(MintPalette.missed))
                        .frame(width: 9, height: 9), text: Text("Ahead"))
            Spacer(minLength: 4)
            Text("Less")
            MintCoin(size: 9, level: 0)
            MintCoin(size: 9, level: 1)
            MintCoin(size: 9, level: 2, glow: true)
            Text("More kept")
        }
        .font(.app(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.leading, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Legend: brighter coins kept more. Small dark dots are missed days, outlines are days ahead."))
    }

    private func legendItem(shape: some View, text: Text) -> some View {
        HStack(spacing: 4) {
            shape
            text
        }
        .padding(.trailing, 4)
    }
}
