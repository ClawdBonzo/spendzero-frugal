import SwiftUI
import SwiftData

struct StreakCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyRecord.date) private var records: [DailyRecord]
    @Query(sort: \SavingsEntry.date, order: .reverse) private var savings: [SavingsEntry]
    @Query(sort: \SpendingLog.date) private var spending: [SpendingLog]
    @Query private var profiles: [UserProfile]
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var detailDay: SelectedDay?
    @AppStorage("streakCalendarMode") private var mode: Mode = .year
    @State private var mintYear = Calendar.current.component(.year, from: Date())
    @State private var zoomDay: SelectedDay?
    @State private var zoomSource: Date?
    @State private var showInsights = false
    @Namespace private var zoomNamespace

    enum Mode: String, CaseIterable { case month, year }

    /// Identifiable wrapper so a tapped day can drive `.sheet(item:)`.
    struct SelectedDay: Identifiable, Hashable {
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

    private var ledger: DayLedger {
        DayLedger(records: records, savings: savings, spending: spending,
                  profileCreated: profiles.first?.createdAt, lastNoSpendDate: profiles.first?.lastNoSpendDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Picker(selection: $mode.animation(.snappy)) {
                        Text("Month").tag(Mode.month)
                        Text("Year").tag(Mode.year)
                    } label: {
                        Text("Calendar view")
                    }
                    .pickerStyle(.segmented)

                    if mode == .year {
                        MintCalendarView(ledger: ledger, year: $mintYear, zoomSource: zoomSource,
                                         zoomNamespace: zoomNamespace) { date in
                            zoomSource = date
                            zoomDay = SelectedDay(date: date)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        monthContent
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.top, 8)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Streak Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.trigger(.buttonTap)
                        showInsights = true
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .tint(AppTheme.primaryGreen)
                    .accessibilityLabel(Text("Progress charts"))
                }
            }
            .navigationDestination(isPresented: $showInsights) { ProgressChartsView() }
            .navigationDestination(item: $zoomDay) { day in
                DayDetailView(date: day.date, record: recordFor(day.date, in: recordsByDay), showsMedallion: true)
                    .navigationTransition(.zoom(sourceID: day.date, in: zoomNamespace))
            }
            .sheet(item: $detailDay) { day in
                DayDetailSheet(date: day.date, record: recordFor(day.date, in: recordsByDay))
            }
            #if DEBUG
            .onAppear {
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-OpenInsights") { showInsights = true }
                if args.contains("-CalendarMonth") { mode = .month }
                if let i = args.firstIndex(of: "-OpenDayOffset"), i + 1 < args.count, let off = Int(args[i + 1]),
                   let d = calendar.date(byAdding: .day, value: -off, to: calendar.startOfDay(for: Date())) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        zoomSource = d
                        zoomDay = SelectedDay(date: d)
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Month mode

    private var monthContent: some View {
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
        }
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DayDetailView(date: date, record: record, showsMedallion: false)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { dismiss() } label: { Text("Done") }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The body of a day's detail, shown pushed (zooming out of its Mint Calendar coin) or in a sheet.
struct DayDetailView: View {
    let date: Date
    let record: DailyRecord?
    var showsMedallion: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var medallionIn = false
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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if showsMedallion && status == .noSpend { medallionHero }
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
            .task { load() }
    }

    /// The day's coin, struck large: the zoom transition lands on it.
    private var medallionHero: some View {
        ZStack {
            Sunburst(color: AppTheme.accentGold, rays: 16, period: 22)
                .frame(width: 300, height: 300)
                .opacity(medallionIn ? 0.9 : 0)
            SealMedallion(center: (record?.totalSpent ?? 0).currencyFormatted,
                          caption: date.formatted(.dateTime.month(.abbreviated).day().year()))
                .frame(width: 180, height: 180)
                .goldSheen()
                .scaleEffect(medallionIn ? 1 : 0.86)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .onAppear {
            if reduceMotion { medallionIn = true; return }
            withAnimation(.spring(duration: 0.55, bounce: 0.35).delay(0.12)) { medallionIn = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Sealed no-spend day medallion"))
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
