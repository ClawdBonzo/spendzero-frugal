import SwiftUI
import Charts

/// Running total saved over the selected window. Draws in left-to-right on appear, scrubs with a
/// drag (rule + callout + a coin tick per day crossed), and marks $100 / $500 / $1,000 … milestones
/// with gold coins. The best week is shaded.
struct CumulativeSavingsChart: View {
    let points: [InsightsSeries.Point]
    let milestones: [InsightsSeries.Milestone]
    let bestWeek: DateInterval?
    let rangeLabel: Text

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0
    @State private var selection: Date?
    @State private var lastTick: Date?

    private var calendar: Calendar { .current }

    private var selectedPoint: InsightsSeries.Point? {
        guard let selection else { return nil }
        let day = calendar.startOfDay(for: selection)
        return points.first { $0.date == day } ?? points.min {
            abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection))
        }
    }

    private var yDomain: ClosedRange<Double> {
        let lo = points.map(\.value).min() ?? 0
        let hi = max(points.map(\.value).max() ?? 0, 50)
        let floor = lo < hi * 0.45 ? 0 : (lo * 0.8 / 50).rounded(.down) * 50
        return floor...(hi * 1.14)
    }

    private var gainInWindow: Double {
        guard let first = points.first, let last = points.last else { return 0 }
        return last.value - first.value + (points.count == 1 ? last.value : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            chart
                .frame(height: 210)
        }
        .onAppear {
            guard reveal == 0 else { return }
            if reduceMotion { reveal = 1; return }
            withAnimation(.easeInOut(duration: 1.1).delay(0.15)) { reveal = 1 }
        }
        .onChange(of: points.first?.date) { _, _ in
            guard !reduceMotion else { return }
            reveal = 0
            withAnimation(.easeInOut(duration: 0.9)) { reveal = 1 }
        }
    }

    // MARK: Header (doubles as the scrub readout)

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if let p = selectedPoint {
                        Text(p.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    } else {
                        Text("Total saved")
                    }
                }
                .font(.app(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                // Not RollingMoney: its built-in haptic would double up with the scrub ticks.
                let shown = selectedPoint?.value ?? (points.last?.value ?? 0) * Double(reveal > 0 ? 1 : 0)
                Text(shown.currencyFormatted)
                    .font(.app(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: shown))
                    .animation(selection == nil ? .snappy(duration: 0.6) : nil, value: shown)
            }
            Spacer()
            if gainInWindow > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.app(size: 11, weight: .heavy))
                    Text("+\(gainInWindow.currencyFormatted)")
                        .font(.app(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(AppTheme.primaryGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.primaryGreen.opacity(0.12)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Up \(gainInWindow.currencyFormatted)"))
            }
        }
    }

    // MARK: Chart

    private var chart: some View {
        let domain = yDomain
        let selected = selectedPoint
        return Chart {
            if let week = bestWeek {
                RectangleMark(xStart: .value("Week start", week.start), xEnd: .value("Week end", week.end))
                    .foregroundStyle(LinearGradient(colors: [AppTheme.accentGold.opacity(0.16), AppTheme.accentGold.opacity(0.03)],
                                                    startPoint: .top, endPoint: .bottom))
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text("Best week")
                            .font(.app(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.accentGold.opacity(0.9))
                            .fixedSize()
                    }
            }

            ForEach(points) { point in
                AreaMark(x: .value("Date", point.date),
                         yStart: .value("Base", domain.lowerBound),
                         yEnd: .value("Saved", point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(
                        colors: [AppTheme.primaryGreen.opacity(0.32), AppTheme.primaryGreen.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom))

                LineMark(x: .value("Date", point.date), y: .value("Saved", point.value))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "00BFA5"), AppTheme.primaryGreen],
                                                    startPoint: .leading, endPoint: .trailing))
            }

            ForEach(milestones) { milestone in
                PointMark(x: .value("Date", milestone.date),
                          y: .value("Saved", points.first { $0.date == milestone.date }?.value ?? milestone.amount))
                    .symbol {
                        MintCoin(size: 15, level: 2, glow: true)
                    }
                    .annotation(position: .top, spacing: 4) {
                        Text(milestone.amount.currencyFormatted)
                            .font(.app(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(AppTheme.accentGold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.background.opacity(0.85)))
                            .fixedSize()
                    }
                    .accessibilityLabel(Text("Milestone \(milestone.amount.currencyFormatted)"))
                    .accessibilityValue(Text(milestone.date, format: .dateTime.month(.wide).day()))
            }

            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.45))
                    .annotation(position: .top, spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        callout(for: selected)
                    }
                PointMark(x: .value("Date", selected.date), y: .value("Saved", selected.value))
                    .symbol {
                        Circle()
                            .fill(AppTheme.primaryGreen)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(AppTheme.background, lineWidth: 2.5))
                            .shadow(color: AppTheme.primaryGreen.opacity(0.8), radius: 6)
                    }
            }
        }
        .chartXScale(domain: (points.first?.date ?? .now)...(points.last?.date ?? .now))
        .chartYScale(domain: domain)
        .chartXSelection(value: $selection)
        .onChange(of: selectedPoint?.date) { old, new in
            guard let new, new != old else { return }
            if let old, milestones.contains(where: { ($0.date > min(old, new)) && ($0.date <= max(old, new)) }) {
                CoinHaptics.seal()
            } else {
                CoinHaptics.tick()
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(AppTheme.textTertiary.opacity(0.35))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.currencyFormatted)
                            .font(.app(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: points.count > 120 ? .dateTime.month(.abbreviated)
                                                               : .dateTime.month(.abbreviated).day())
                            .font(.app(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.mask(alignment: .leading) {
                // Taller and wider than the plot so annotations above coins aren't clipped.
                Rectangle()
                    .padding(.vertical, -44)
                    .padding(.horizontal, -24)
                    .scaleEffect(x: reveal, anchor: .leading)
            }
        }
        .accessibilityChartDescriptor(DateValueChartDescriptor(
            title: String(localized: "Total saved"),
            summary: String(localized: "Running total of everything you've saved, with gold coins at each savings milestone."),
            seriesName: String(localized: "Total saved"),
            points: points.map { ($0.date, $0.value) }))
    }

    private func callout(for point: InsightsSeries.Point) -> some View {
        VStack(spacing: 1) {
            Text(point.value.currencyFormatted)
                .font(.app(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
            Text(point.date, format: .dateTime.month(.abbreviated).day())
                .font(.app(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(AppTheme.surfaceElevated)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
        )
        .fixedSize()
    }
}
