import SwiftUI
import SwiftData
import Charts

struct ProgressChartsView: View {
    @Query(sort: \SavingsEntry.date) private var savings: [SavingsEntry]
    @Query(sort: \SpendingLog.date) private var spending: [SpendingLog]
    @Query(sort: \ImpulseLog.date) private var impulses: [ImpulseLog]
    @State private var selectedTimeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "90D"
    }

    private var filteredSavings: [SavingsEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysForRange, to: Date()) ?? Date()
        return savings.filter { $0.date >= cutoff }
    }

    private var filteredSpending: [SpendingLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysForRange, to: Date()) ?? Date()
        return spending.filter { $0.date >= cutoff }
    }

    private var daysForRange: Int {
        switch selectedTimeRange {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }

    private var totalSavedInRange: Double {
        filteredSavings.reduce(0) { $0 + $1.amount }
    }

    private var totalSpentInRange: Double {
        filteredSpending.reduce(0) { $0 + $1.amount }
    }

    private var impulsesResistedCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysForRange, to: Date()) ?? Date()
        return impulses.filter { $0.date >= cutoff && $0.wasResisted }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Time range picker
                    Picker("Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Summary cards
                    HStack(spacing: 12) {
                        MiniStatCard(title: "Saved", value: "$\(Int(totalSavedInRange))", color: AppTheme.primaryGreen)
                        MiniStatCard(title: "Spent", value: "$\(Int(totalSpentInRange))", color: AppTheme.destructive)
                        MiniStatCard(title: "Resisted", value: "\(impulsesResistedCount)", color: AppTheme.info)
                    }

                    // Savings Growth Chart
                    savingsGrowthChart

                    // Spending by Category
                    spendingByCategoryChart

                    // Impulse Trend
                    impulseTrendChart

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.top, 8)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Savings Growth Chart

    private var savingsGrowthChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Savings Growth")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            if filteredSavings.isEmpty {
                chartEmptyState
            } else {
                Chart {
                    ForEach(cumulativeSavingsData, id: \.date) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Saved", point.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.primaryGreen.opacity(0.3), AppTheme.primaryGreen.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Saved", point.amount)
                        )
                        .foregroundStyle(AppTheme.primaryGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text("$\(Int(val))")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                }
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.cardBackground)
        )
    }

    // MARK: - Spending by Category

    private var spendingByCategoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            if filteredSpending.isEmpty {
                chartEmptyState
            } else {
                let categoryData = Dictionary(grouping: filteredSpending, by: \.category)
                    .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
                    .sorted { $0.total > $1.total }

                Chart(categoryData, id: \.category) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.6),
                        angularInset: 2
                    )
                    .foregroundStyle(Color(hex: item.category.color))
                    .cornerRadius(4)
                }
                .frame(height: 200)

                // Legend
                VStack(spacing: 6) {
                    ForEach(categoryData.prefix(5), id: \.category) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: item.category.color))
                                .frame(width: 8, height: 8)
                            Text(item.category.rawValue)
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("$\(Int(item.total))")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                }
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.cardBackground)
        )
    }

    // MARK: - Impulse Trend

    private var impulseTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Impulse Control")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            let cutoff = Calendar.current.date(byAdding: .day, value: -daysForRange, to: Date()) ?? Date()
            let filtered = impulses.filter { $0.date >= cutoff }
            let resisted = filtered.filter(\.wasResisted).count
            let total = filtered.count

            if total == 0 {
                chartEmptyState
            } else {
                HStack(spacing: 20) {
                    // Ring chart
                    ZStack {
                        Circle()
                            .stroke(AppTheme.destructive.opacity(0.2), lineWidth: 12)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: total > 0 ? Double(resisted) / Double(total) : 0)
                            .stroke(AppTheme.primaryGreen, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(total > 0 ? Int(Double(resisted) / Double(total) * 100) : 0)%")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primaryGreen)
                            Text("Resisted")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(resisted)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primaryGreen)
                            Text("Impulses Resisted")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(total - resisted)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.destructive)
                            Text("Given In")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.cardBackground)
        )
    }

    // MARK: - Helpers

    private var chartEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundColor(AppTheme.textTertiary)
            Text("No data yet")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private var cumulativeSavingsData: [(date: Date, amount: Double)] {
        var cumulative = 0.0
        var result: [(date: Date, amount: Double)] = []
        for entry in filteredSavings {
            cumulative += entry.amount
            result.append((date: entry.date, amount: cumulative))
        }
        return result
    }
}

struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
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
