import SwiftUI
import SwiftData
import Charts

struct ProgressChartsView: View {
    @Query(sort: \SavingsEntry.date) private var savings: [SavingsEntry]
    @Query(sort: \SpendingLog.date) private var spending: [SpendingLog]
    @Query(sort: \ImpulseLog.date) private var impulses: [ImpulseLog]
    @Query(sort: \DailyRecord.date) private var records: [DailyRecord]
    @Query private var profiles: [UserProfile]
    @State private var selectedTimeRange: TimeRange = .month

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "90D"
        case year = "1Y"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            }
        }
    }

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var windowStart: Date { calendar.date(byAdding: .day, value: -(selectedTimeRange.days - 1), to: today) ?? today }
    private var window: DateInterval {
        DateInterval(start: windowStart, end: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
    }

    private var ledger: DayLedger {
        DayLedger(records: records, savings: savings, spending: spending,
                  profileCreated: profiles.first?.createdAt, lastNoSpendDate: profiles.first?.lastNoSpendDate)
    }

    private var totalSavedAllTime: Double {
        profiles.first?.totalSaved ?? savings.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        let ledger = ledger
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Picker(selection: $selectedTimeRange.animation(.snappy)) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(LocalizedStringKey(range.rawValue)).tag(range)
                    }
                } label: {
                    Text("Range")
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTimeRange) { _, _ in CoinHaptics.tick() }

                savingsCard
                SavingsEquivalentsCard(totalSaved: totalSavedAllTime)
                spendCard(ledger)
                bestWeekCard(ledger)
                urgesCard

                Spacer(minLength: 100)
            }
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.top, 8)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - (a) Cumulative savings

    @ViewBuilder
    private var savingsCard: some View {
        let ledger = ledger
        let points = InsightsSeries.cumulative(savings: savings, from: windowStart, through: today)
        let baseline = InsightsSeries.cumulative(savings: savings,
                                                 from: calendar.date(byAdding: .day, value: -1, to: windowStart) ?? windowStart,
                                                 through: calendar.date(byAdding: .day, value: -1, to: windowStart) ?? windowStart)
            .first?.value ?? 0
        let best = InsightsSeries.bestWeek(ledger: ledger, in: window)
        let bestInterval = best.flatMap { week -> DateInterval? in
            guard let end = calendar.date(byAdding: .day, value: 6, to: week.start) else { return nil }
            let s = max(week.start, windowStart), e = min(end, today)
            return s < e ? DateInterval(start: s, end: e) : nil
        }
        InsightCard(Text("Savings growth")) {
            if savings.isEmpty {
                ChartEmptyState(icon: "chart.line.uptrend.xyaxis", title: Text("Your line starts here"),
                                message: Text("Seal a no-spend day or resist an urge and watch your total climb."))
            } else {
                CumulativeSavingsChart(points: points,
                                       milestones: InsightsSeries.milestones(in: points, baseline: baseline),
                                       bestWeek: selectedTimeRange == .week ? nil : bestInterval,
                                       rangeLabel: Text(LocalizedStringKey(selectedTimeRange.rawValue)))
                    .id(selectedTimeRange)
            }
        }
    }

    // MARK: - (b) Spend vs budget

    private func spendCard(_ ledger: DayLedger) -> some View {
        let days = min(selectedTimeRange.days, 30)
        let bars = InsightsSeries.dailyBars(ledger: ledger, days: days)
        let sealed = bars.filter(\.sealed).count
        let hasData = bars.contains { $0.spent > 0 || $0.sealed }
        return InsightCard(Text("Spending vs budget"),
                           subtitle: days == 7 ? Text("Last 7 days · \(sealed) no-spend") : Text("Last 30 days · \(sealed) no-spend")) {
            if hasData {
                SpendVsBudgetChart(bars: bars, budget: profiles.first?.dailyBudget ?? 0)
                    .id(days)
            } else {
                ChartEmptyState(icon: "chart.bar.fill", title: Text("Nothing logged yet"),
                                message: Text("Log spending or seal a day and your bars appear here."))
            }
        }
    }

    // MARK: - (c) Urges ring

    private var urgesCard: some View {
        let inWindow = impulses.filter { $0.date >= windowStart }
        let data = InsightsSeries.urgesByCategory(inWindow)
        let givenIn = inWindow.filter { !$0.wasResisted }.count
        return InsightCard(Text("Urges resisted")) {
            if data.isEmpty {
                ChartEmptyState(icon: "bolt.slash.fill", title: Text("No urges logged in this period"),
                                message: Text("When you resist an impulse buy, log it: each one lands in this ring."))
            } else {
                UrgeRingChart(data: data, givenIn: givenIn)
                    .id(selectedTimeRange)
            }
        }
    }

    // MARK: - (d) Best week

    private func bestWeekCard(_ ledger: DayLedger) -> some View {
        let lookback = DateInterval(start: calendar.date(byAdding: .day, value: -365, to: today) ?? today, end: today)
        let best = InsightsSeries.bestWeek(ledger: ledger, in: lookback)
        return InsightCard(Text("Your best week")) {
            if let best {
                BestWeekView(week: best, today: today)
            } else {
                ChartEmptyState(icon: "trophy.fill", title: Text("Your best week is ahead"),
                                message: Text("Keep money in your pocket for a few days and we'll crown it here."))
            }
        }
    }
}

// MARK: - Best week

private struct BestWeekView: View {
    let week: InsightsSeries.Week
    let today: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var end: Date { Calendar.current.date(byAdding: .day, value: 6, to: week.start) ?? week.start }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(week.start.formatted(.dateTime.month(.abbreviated).day()) + " – "
                         + end.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.app(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                    RollingMoney(value: shown ? week.kept : 0,
                                 font: .app(size: 30, weight: .black, design: .rounded),
                                 color: AppTheme.accentGold)
                        .goldSheen()
                }
                Spacer()
                Text("\(week.sealedCount)/7 sealed")
                    .font(.app(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.accentGold.opacity(0.14)))
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let day = Calendar.current.date(byAdding: .day, value: i, to: week.start) ?? week.start
                    VStack(spacing: 6) {
                        Group {
                            if week.sealedDays[i] {
                                MintCoin(size: 26, level: 2, glow: true)
                            } else if day > today {
                                Circle().strokeBorder(MintPalette.missed, lineWidth: 1.5).frame(width: 22, height: 22)
                            } else {
                                Circle().fill(MintPalette.missed).frame(width: 18, height: 18)
                            }
                        }
                        .frame(height: 30)
                        .scaleEffect(shown ? 1 : 0.3)
                        .opacity(shown ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.5).delay(0.25 + Double(i) * 0.06),
                                   value: shown)
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.app(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide)))
                    .accessibilityValue(week.sealedDays[i] ? Text("Sealed") : Text("Not sealed"))
                }
            }
        }
        .onAppear {
            if reduceMotion { shown = true } else { withAnimation(.snappy) { shown = true } }
        }
    }
}

struct MiniStatCard: View {
    let title: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.app(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.app(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(AppTheme.cardBackground)
        )
    }
}
