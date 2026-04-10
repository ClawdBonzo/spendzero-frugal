import SwiftUI
import SwiftData

struct StreakCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.date) private var records: [DailyRecord]
    @Query(sort: \SavingsEntry.date) private var savings: [SavingsEntry]
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var showSummary = false
    @State private var showCalendar = false
    @State private var showTimeline = false

    private var calendar: Calendar { Calendar.current }

    private var monthDays: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedMonth) else { return [] }
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        return range.compactMap { day -> Date? in
            var dc = components
            dc.day = day
            return calendar.date(from: dc)
        }
    }

    private var firstWeekday: Int {
        guard let first = monthDays.first else { return 0 }
        return (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
    }

    private func recordFor(_ date: Date) -> DailyRecord? {
        records.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func savingsFor(_ date: Date) -> Double {
        savings
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthTotal: Double {
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        return savings.filter {
            let sc = calendar.dateComponents([.year, .month], from: $0.date)
            return sc.year == components.year && sc.month == components.month
        }.reduce(0) { $0 + $1.amount }
    }

    private var streakDaysThisMonth: Int {
        monthDays.filter { recordFor($0)?.isNoSpendDay == true }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Month navigator
                    monthNavigator

                    // Month summary — slides in
                    monthSummaryCard
                        .scaleEffect(showSummary ? 1 : 0.92)
                        .opacity(showSummary ? 1 : 0)

                    // Calendar grid — fades in
                    calendarGrid
                        .offset(y: showCalendar ? 0 : 20)
                        .opacity(showCalendar ? 1 : 0)

                    // Savings timeline — slides up
                    savingsTimeline
                        .offset(y: showTimeline ? 0 : 25)
                        .opacity(showTimeline ? 1 : 0)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.top, 8)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                        showSummary = true
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                        showCalendar = true
                    }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3)) {
                        showTimeline = true
                    }
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Streak Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                HapticManager.shared.trigger(.swipe)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { changeMonth(by: -1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text(selectedMonth, format: .dateTime.month(.wide).year())
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)
                .contentTransition(.numericText())

            Spacer()

            Button {
                HapticManager.shared.trigger(.swipe)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { changeMonth(by: 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Month Summary

    private var monthSummaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(streakDaysThisMonth)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.primaryGreen)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: streakDaysThisMonth)
                Text("No-Spend Days")
                    .font(AppTheme.smallFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)
                .background(AppTheme.textTertiary.opacity(0.3))

            VStack(spacing: 4) {
                Text("$\(Int(monthTotal))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.accentGold)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4), value: monthTotal)
                Text("Month Saved")
                    .font(AppTheme.smallFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.cardBackground)
        )
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                // Empty cells for offset
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }

                // Day cells
                ForEach(monthDays, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        record: recordFor(date),
                        saved: savingsFor(date),
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                        isToday: calendar.isDateInToday(date)
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDate = date
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

    // MARK: - Savings Timeline

    private var savingsTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Savings Timeline")
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)

            let recentSavings = savings.prefix(10)
            if recentSavings.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No savings yet",
                    subtitle: "Complete your first no-spend day to start!"
                )
            } else {
                ForEach(Array(recentSavings)) { entry in
                    HStack(spacing: 12) {
                        Image(systemName: entry.source.icon)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.primaryGreen)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(AppTheme.primaryGreen.opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.source.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            Text(entry.date, format: .dateTime.month().day().hour().minute())
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        Spacer()

                        Text("+$\(Int(entry.amount))")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.primaryGreen)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            .fill(AppTheme.cardBackground)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
}

struct CalendarDayCell: View {
    let date: Date
    let record: DailyRecord?
    let saved: Double
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    private var day: Int { Calendar.current.component(.day, from: date) }
    private var isFuture: Bool { date > Date() }

    var body: some View {
        Button {
            HapticManager.shared.trigger(.cardSelect)
            action()
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(dayColor)

                if record?.isNoSpendDay == true {
                    Circle()
                        .fill(AppTheme.primaryGreen)
                        .frame(width: 6, height: 6)
                } else if record != nil {
                    Circle()
                        .fill(AppTheme.destructive)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? AppTheme.primaryGreen : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var dayColor: Color {
        if isFuture { return AppTheme.textTertiary.opacity(0.4) }
        if isSelected { return AppTheme.textPrimary }
        return AppTheme.textSecondary
    }

    private var backgroundColor: Color {
        if isSelected { return AppTheme.primaryGreen.opacity(0.15) }
        return Color.clear
    }
}
