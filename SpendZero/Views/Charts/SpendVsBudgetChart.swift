import SwiftUI
import Charts

/// Daily spending against the daily budget, with every sealed no-spend day minted as a small gold
/// coin on the baseline. Bars over the line are over budget (position, not just colour, tells you).
struct SpendVsBudgetChart: View {
    let bars: [InsightsSeries.DayBar]
    let budget: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grow: Double = 0

    private var maxSpent: Double { bars.map(\.spent).max() ?? 0 }
    private var top: Double { max(maxSpent, budget) * 1.18 }
    /// Room under zero so the coins sit on the baseline without being clipped.
    private var floor: Double { -top * 0.09 }
    private var sealedCount: Int { bars.filter(\.sealed).count }
    private var overCount: Int { bars.filter { $0.spent > budget }.count }
    private var coinSize: CGFloat { bars.count > 20 ? 7 : 11 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chart
                .frame(height: 170)
            legend
        }
        .onAppear {
            guard grow == 0 else { return }
            if reduceMotion { grow = 1; return }
            withAnimation(.spring(duration: 0.8, bounce: 0.2).delay(0.2)) { grow = 1 }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                if bar.spent > 0 {
                    BarMark(x: .value("Day", bar.date, unit: .day),
                            yStart: .value("Spent", 0),
                            yEnd: .value("Spent", bar.spent * grow),
                            width: .ratio(0.62))
                        .cornerRadius(3)
                        .foregroundStyle(bar.spent > budget
                                         ? AnyShapeStyle(LinearGradient(colors: [AppTheme.destructive, AppTheme.destructive.opacity(0.55)],
                                                                        startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(LinearGradient(colors: [Color(hex: "6F8399"), Color(hex: "3A4757")],
                                                                        startPoint: .top, endPoint: .bottom)))
                        .accessibilityLabel(Text(bar.date, format: .dateTime.weekday(.wide).month().day()))
                        .accessibilityValue(Text(bar.spent > budget
                                                 ? "\(bar.spent.currencyFormatted) spent, over budget"
                                                 : "\(bar.spent.currencyFormatted) spent"))
                }
                if bar.sealed {
                    PointMark(x: .value("Day", bar.date, unit: .day), y: .value("Spent", 0))
                        .symbol { MintCoin(size: coinSize, level: 1).scaleEffect(grow) }
                        .accessibilityLabel(Text(bar.date, format: .dateTime.weekday(.wide).month().day()))
                        .accessibilityValue(Text("No-spend day"))
                }
            }

            if budget > 0 {
                RuleMark(y: .value("Budget", budget))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .foregroundStyle(AppTheme.accentGold.opacity(0.75))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("Budget \(budget.currencyFormatted)")
                            .font(.app(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.accentGold)
                            .fixedSize()
                    }
                    .accessibilityLabel(Text("Daily budget"))
                    .accessibilityValue(Text(budget.currencyFormatted))
            }
        }
        .chartYScale(domain: floor...top)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, top / 1.18]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                    .foregroundStyle(AppTheme.textTertiary.opacity(0.3))
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
            AxisMarks(values: .stride(by: .day, count: bars.count > 10 ? 7 : 1)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: bars.count > 10 ? .dateTime.month(.abbreviated).day() : .dateTime.weekday(.narrow))
                            .font(.app(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
        .accessibilityChartDescriptor(DateValueChartDescriptor(
            title: String(localized: "Spending vs budget"),
            summary: String(localized: "\(sealedCount) no-spend days and \(overCount) days over budget."),
            seriesName: String(localized: "Spent"),
            points: bars.map { ($0.date, $0.spent) },
            categorical: true))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                MintCoin(size: 10, level: 1)
                Text("No-spend day")
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "6F8399")).frame(width: 8, height: 11)
                Text("Spent")
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(AppTheme.destructive).frame(width: 8, height: 11)
                Text("Over budget")
            }
            Spacer(minLength: 0)
        }
        .font(.app(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(AppTheme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityHidden(true)
    }
}
