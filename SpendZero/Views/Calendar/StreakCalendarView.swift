import SwiftUI
import SwiftData

struct StreakCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.date) private var records: [DailyRecord]
    @Query(sort: \SavingsEntry.date, order: .reverse) private var savings: [SavingsEntry]
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var detailDay: SelectedDay?

    /// Identifiable wrapper so a tapped day can drive `.sheet(item:)`.
    struct SelectedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }
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

    /// Locale-aware, rotated so the first column matches `calendar.firstWeekday`.
    private var weekdayHeaders: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var firstWeekday: Int {
        guard let first = monthDays.first else { return 0 }
        return (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
    }

    // Build day-keyed lookup tables ONCE per render instead of scanning the full
    // records/savings arrays for every visible calendar cell (was O(days × rows)).
    private var recordsByDay: [Date: DailyRecord] {
        Dictionary(records.map { (calendar.startOfDay(for: $0.date), $0) },
                   uniquingKeysWith: { _, new in new })
    }

    private var savingsByDay: [Date: Double] {
        var totals: [Date: Double] = [:]
        for entry in savings {
            totals[calendar.startOfDay(for: entry.date), default: 0] += entry.amount
        }
        return totals
    }

    private func recordFor(_ date: Date, in table: [Date: DailyRecord]) -> DailyRecord? {
        table[calendar.startOfDay(for: date)]
    }

    private func savingsFor(_ date: Date, in table: [Date: Double]) -> Double {
        table[calendar.startOfDay(for: date)] ?? 0
    }

    private var monthTotal: Double {
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)
        return savings.filter {
            let sc = calendar.dateComponents([.year, .month], from: $0.date)
            return sc.year == components.year && sc.month == components.month
        }.reduce(0) { $0 + $1.amount }
    }

    private var streakDaysThisMonth: Int {
        let table = recordsByDay
        return monthDays.filter { recordFor($0, in: table)?.isNoSpendDay == true }.count
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
            .sheet(item: $detailDay) { day in
                DayDetailSheet(date: day.date, record: recordFor(day.date, in: recordsByDay))
            }
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
                    .font(.app(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .accessibilityLabel(Text("Previous month"))

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
                    .font(.app(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .accessibilityLabel(Text("Next month"))
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Month Summary

    private var monthSummaryCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(streakDaysThisMonth)")
                    .font(.app(size: 28, weight: .bold, design: .rounded))
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
                Text(monthTotal.currencyFormatted)
                    .font(.app(size: 28, weight: .bold, design: .rounded))
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
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.app(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            let recordTable = recordsByDay
            let savingsTable = savingsByDay
            LazyVGrid(columns: columns, spacing: 4) {
                // Empty cells for offset
                ForEach(0..<firstWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }

                // Day cells
                ForEach(monthDays, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        record: recordFor(date, in: recordTable),
                        saved: savingsFor(date, in: savingsTable),
                        isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false,
                        isToday: calendar.isDateInToday(date)
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDate = date
                        }
                        detailDay = SelectedDay(date: date)
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
                            .font(.app(size: 16))
                            .foregroundColor(AppTheme.primaryGreen)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(AppTheme.primaryGreen.opacity(0.12))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(entry.source.rawValue))
                                .font(.app(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.textPrimary)
                            Text(entry.date, format: .dateTime.month().day().hour().minute())
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                        }

                        Spacer()

                        Text("+\(entry.amount.currencyFormatted)")
                            .font(.app(size: 16, weight: .bold, design: .rounded))
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
                    .font(.app(size: 14, weight: isToday ? .bold : .regular))
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

// MARK: - Day Detail

/// Everything logged on one calendar day. Spending and impulses are fetched with a date-range
/// predicate so only that day's rows are loaded.
struct DayDetailSheet: View {
    let date: Date
    let record: DailyRecord?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var spending: [SpendingLog] = []
    @State private var impulses: [ImpulseLog] = []

    private enum Status { case noSpend, spent, notLogged }

    private var status: Status {
        guard let record else { return .notLogged }
        return (record.isNoSpendDay && !hasNonEssential) ? .noSpend : .spent
    }

    private var hasNonEssential: Bool { spending.contains { !$0.category.isEssential } }

    private var wins: [WinItem] {
        guard let record else { return [] }
        return WinItem.all.filter { record.wins.contains($0.title) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    statusHeader
                    totalsRow

                    if !wins.isEmpty {
                        section(title: Text("Wins")) {
                            ForEach(wins, id: \.title) { win in
                                HStack(spacing: 10) {
                                    Image(systemName: win.icon)
                                        .foregroundColor(AppTheme.primaryGreen)
                                        .frame(width: 24)
                                    Text(win.label)
                                        .font(.app(size: 14, weight: .medium))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Text(verbatim: "+\(win.saved)")
                                        .font(.app(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.primaryGreen)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium).fill(AppTheme.cardBackground))
                            }
                        }
                    }

                    if !spending.isEmpty {
                        section(title: Text("Spending")) {
                            ForEach(spending) { SpendingLogRow(log: $0) }
                        }
                    }

                    if !impulses.isEmpty {
                        section(title: Text("Impulses")) {
                            ForEach(impulses) { ImpulseLogRow(impulse: $0) }
                        }
                    }

                    if record == nil && spending.isEmpty && impulses.isEmpty {
                        EmptyStateView(icon: "calendar",
                                       title: "Nothing logged",
                                       subtitle: "No entries were recorded on this day.")
                    }

                    Spacer(minLength: 40)
                }
                .padding(AppTheme.paddingMedium)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(Text(date, format: .dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Text("Done") }
                }
            }
            .task { load() }
        }
        .presentationDetents([.medium, .large])
    }

    private var statusHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.app(size: 22))
                .foregroundColor(statusColor)
            statusTitle
                .font(AppTheme.headlineFont)
                .foregroundColor(statusColor)
            Spacer()
        }
        .padding(AppTheme.paddingMedium)
        .background(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge).fill(statusColor.opacity(0.1)))
    }

    private var totalsRow: some View {
        HStack(spacing: 12) {
            StatCard(title: "Spent", value: (record?.totalSpent ?? 0).currencyFormattedDecimal,
                     icon: "creditcard.fill", color: AppTheme.destructive)
            StatCard(title: "Saved", value: (record?.totalSaved ?? 0).currencyFormatted,
                     icon: "dollarsign.circle.fill", color: AppTheme.primaryGreen)
        }
    }

    private func section<Content: View>(title: Text, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            title
                .font(AppTheme.headlineFont)
                .foregroundColor(AppTheme.textPrimary)
            content()
        }
    }

    private var statusIcon: String {
        switch status {
        case .noSpend: return "checkmark.seal.fill"
        case .spent: return "xmark.seal.fill"
        case .notLogged: return "minus.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .noSpend: return AppTheme.primaryGreen
        case .spent: return AppTheme.destructive
        case .notLogged: return AppTheme.textSecondary
        }
    }

    private var statusTitle: Text {
        switch status {
        case .noSpend: return Text("No-Spend Day")
        case .spent: return Text("Spent")
        case .notLogged: return Text("Not logged")
        }
    }

    private func load() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? date
        let spendDescriptor = FetchDescriptor<SpendingLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        let impulseDescriptor = FetchDescriptor<ImpulseLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        spending = (try? modelContext.fetch(spendDescriptor)) ?? []
        impulses = (try? modelContext.fetch(impulseDescriptor)) ?? []
    }
}
