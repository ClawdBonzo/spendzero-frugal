import Foundation

// Pure, view-independent computations behind the Mint Calendar and the Progress charts.
// Everything here takes plain arrays of model values so it never touches a ModelContext and
// never mutates a model.

// MARK: - Day ledger

/// One calendar day's no-spend status, derived from DailyRecord + SavingsEntry + SpendingLog.
struct DayLedger {
    /// Start-of-day → amount kept that day (savings credited, or the record's total if larger).
    let kept: [Date: Double]
    /// Days that count as sealed no-spend days.
    let sealed: Set<Date>
    /// Start-of-day → total logged spending that day.
    let spent: [Date: Double]
    /// First day the user was tracking anything. Days before this are "not started", not "missed".
    let trackingStart: Date
    let today: Date
    let calendar: Calendar

    init(records: [DailyRecord], savings: [SavingsEntry], spending: [SpendingLog],
         profileCreated: Date?, lastNoSpendDate: Date?, now: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        let today = calendar.startOfDay(for: now)
        self.today = today

        var kept: [Date: Double] = [:]
        var markedDays = Set<Date>()
        for entry in savings {
            let day = calendar.startOfDay(for: entry.date)
            kept[day, default: 0] += entry.amount
            if entry.source == .noSpendDay { markedDays.insert(day) }
        }
        var spent: [Date: Double] = [:]
        var nonEssentialDays = Set<Date>()
        for log in spending {
            let day = calendar.startOfDay(for: log.date)
            spent[day, default: 0] += log.amount
            if !log.category.isEssential { nonEssentialDays.insert(day) }
        }

        var sealed = markedDays
        var earliest = today
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            earliest = min(earliest, day)
            kept[day] = max(kept[day] ?? 0, record.totalSaved)
            // Past days keep the record's verdict (this is what the month grid has always shown).
            // Today only counts once it has actually been marked.
            if day < today, record.isNoSpendDay, !nonEssentialDays.contains(day) { sealed.insert(day) }
        }
        if let last = lastNoSpendDate, calendar.isDate(last, inSameDayAs: today), !nonEssentialDays.contains(today) {
            sealed.insert(today)
        }
        sealed.subtract(nonEssentialDays.subtracting(markedDays))
        if let first = savings.map(\.date).min() { earliest = min(earliest, calendar.startOfDay(for: first)) }
        if let first = spending.map(\.date).min() { earliest = min(earliest, calendar.startOfDay(for: first)) }
        if let created = profileCreated { earliest = min(earliest, calendar.startOfDay(for: created)) }

        self.kept = kept
        self.sealed = sealed
        self.spent = spent
        self.trackingStart = earliest
    }

    func isSealed(_ day: Date) -> Bool { sealed.contains(day) }
    func keptOn(_ day: Date) -> Double { kept[day] ?? 0 }

    /// Years that contain any tracked day, oldest first (always includes the current year).
    var years: [Int] {
        let first = calendar.component(.year, from: trackingStart)
        let last = calendar.component(.year, from: today)
        return Array(first...max(first, last))
    }

    /// Length of the longest run of consecutive sealed days whose days fall inside `interval`.
    func longestRun(in interval: DateInterval) -> Int {
        let days = sealed.filter { interval.contains($0) && $0 < interval.end }.sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }
}

// MARK: - Mint year

/// The year grid: one row per month, one coin per day.
struct MintYear {
    enum State: Equatable {
        /// A sealed no-spend day; `level` 0…2 is brightness by amount kept, `glow` marks the top days.
        case sealed(level: Int, glow: Bool)
        case missed
        case today
        case future
        /// Before the user started tracking.
        case dormant
    }

    struct Day: Identifiable, Equatable {
        let date: Date
        let month: Int   // 0-based
        let day: Int     // 0-based
        let state: State
        let kept: Double
        var id: Date { date }
    }

    struct Month: Identifiable {
        let index: Int
        let start: Date
        let days: [Day]
        var sealedCount: Int { days.filter { if case .sealed = $0.state { true } else { false } }.count }
        var kept: Double { days.reduce(0) { $0 + (isSealedState($1.state) ? $1.kept : 0) } }
        var id: Int { index }
    }

    let year: Int
    let months: [Month]
    let sealedCount: Int
    let longestStreak: Int
    let keptTotal: Double
    /// Kept-amount thresholds between brightness levels (for the legend and VoiceOver).
    let levelThresholds: [Double]

    init(year: Int, ledger: DayLedger) {
        self.year = year
        let cal = ledger.calendar
        let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? ledger.today
        let yearEnd = cal.date(byAdding: .year, value: 1, to: yearStart) ?? ledger.today
        let interval = DateInterval(start: yearStart, end: yearEnd)

        // Brightness is relative to this user's own sealed days in the year, so it reads well
        // whatever their budget: terciles for the three levels, the top ~8% glow.
        let sealedAmounts = ledger.sealed.filter { interval.contains($0) && $0 < yearEnd }
            .map { ledger.keptOn($0) }.sorted()
        func quantile(_ q: Double) -> Double {
            guard !sealedAmounts.isEmpty else { return 0 }
            let i = min(sealedAmounts.count - 1, max(0, Int((Double(sealedAmounts.count - 1) * q).rounded())))
            return sealedAmounts[i]
        }
        let t1 = quantile(1.0 / 3), t2 = quantile(2.0 / 3), tGlow = quantile(0.92)
        let distinct = Set(sealedAmounts).count > 1
        levelThresholds = [t1, t2, tGlow]

        var months: [Month] = []
        var sealedCount = 0
        var keptTotal = 0.0
        for m in 0..<12 {
            guard let monthStart = cal.date(byAdding: .month, value: m, to: yearStart),
                  let range = cal.range(of: .day, in: .month, for: monthStart) else { continue }
            var days: [Day] = []
            for d in 0..<range.count {
                guard let date = cal.date(byAdding: .day, value: d, to: monthStart) else { continue }
                let kept = ledger.keptOn(date)
                let state: State
                if ledger.isSealed(date) {
                    let level = !distinct ? 1 : (kept > t2 ? 2 : (kept > t1 ? 1 : 0))
                    state = .sealed(level: level, glow: distinct && kept >= tGlow && kept > t2)
                    sealedCount += 1
                    keptTotal += kept
                } else if date == ledger.today {
                    state = .today
                } else if date > ledger.today {
                    state = .future
                } else if date < ledger.trackingStart {
                    state = .dormant
                } else {
                    state = .missed
                }
                days.append(Day(date: date, month: m, day: d, state: state, kept: kept))
            }
            months.append(Month(index: m, start: monthStart, days: days))
        }
        self.months = months
        self.sealedCount = sealedCount
        self.keptTotal = keptTotal
        self.longestStreak = ledger.longestRun(in: interval)
    }

    /// Month with the most sealed days (ties go to the one that kept more). Nil if nothing sealed.
    var bestMonth: Month? {
        months.filter { $0.sealedCount > 0 }.max { a, b in
            a.sealedCount != b.sealedCount ? a.sealedCount < b.sealedCount : a.kept < b.kept
        }
    }
}

func isSealedState(_ state: MintYear.State) -> Bool {
    if case .sealed = state { return true }
    return false
}

// MARK: - Chart series

enum InsightsSeries {
    struct Point: Identifiable, Equatable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    struct Milestone: Identifiable, Equatable {
        let amount: Double
        let date: Date
        var id: Double { amount }
    }

    struct DayBar: Identifiable, Equatable {
        let date: Date
        let spent: Double
        let sealed: Bool
        var id: Date { date }
    }

    struct CategoryCount: Identifiable, Equatable {
        let category: SpendCategory
        let count: Int
        let value: Double
        var id: String { category.rawValue }
    }

    struct Week: Equatable {
        let start: Date
        let kept: Double
        let sealedDays: [Bool]   // one per day of the week, in order
        var sealedCount: Int { sealedDays.filter { $0 }.count }
    }

    /// The milestone ladder: $100, $500, $1,000, $2,500, $5,000, $10,000, …
    static func milestoneLadder(upTo maxValue: Double) -> [Double] {
        var ladder: [Double] = [100, 500]
        var step = 1000.0
        while step <= max(maxValue, 1000) {
            ladder.append(step)
            ladder.append(step * 2.5)
            ladder.append(step * 5)
            step *= 10
        }
        return ladder.filter { $0 <= maxValue }.sorted()
    }

    /// All-time running total of savings, one point per day from `start` through `end` (inclusive),
    /// so the line is continuous and every day can be scrubbed.
    static func cumulative(savings: [SavingsEntry], from start: Date, through end: Date,
                           calendar: Calendar = .current) -> [Point] {
        let s = calendar.startOfDay(for: start), e = calendar.startOfDay(for: end)
        var perDay: [Date: Double] = [:]
        var before = 0.0
        for entry in savings {
            let day = calendar.startOfDay(for: entry.date)
            if day < s { before += entry.amount } else if day <= e { perDay[day, default: 0] += entry.amount }
        }
        var points: [Point] = []
        var running = before
        var day = s
        while day <= e {
            running += perDay[day] ?? 0
            points.append(Point(date: day, value: running))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return points
    }

    /// The first day on which each ladder milestone was reached, for milestones crossed inside the
    /// window (`baseline` is the running total the day before the window opened).
    static func milestones(in points: [Point], baseline: Double) -> [Milestone] {
        guard let last = points.last else { return [] }
        return milestoneLadder(upTo: last.value).compactMap { amount in
            guard amount > baseline, let hit = points.first(where: { $0.value >= amount }) else { return nil }
            return Milestone(amount: amount, date: hit.date)
        }
    }

    static func dailyBars(ledger: DayLedger, days: Int) -> [DayBar] {
        let cal = ledger.calendar
        return (0..<days).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: ledger.today) else { return nil }
            return DayBar(date: day, spent: ledger.spent[day] ?? 0, sealed: ledger.isSealed(day))
        }
    }

    static func urgesByCategory(_ impulses: [ImpulseLog]) -> [CategoryCount] {
        Dictionary(grouping: impulses.filter(\.wasResisted), by: \.category)
            .map { CategoryCount(category: $0.key, count: $0.value.count,
                                 value: $0.value.reduce(0) { $0 + $1.estimatedCost }) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.value > $1.value }
    }

    /// The calendar week (locale's first weekday) that kept the most, among weeks overlapping
    /// `interval`. Ties go to the more recent week. Nil if nothing was kept.
    static func bestWeek(ledger: DayLedger, in interval: DateInterval) -> Week? {
        let cal = ledger.calendar
        var weeks: [Date: Double] = [:]
        for (day, amount) in ledger.kept where amount > 0 && day >= interval.start && day <= interval.end {
            guard let start = cal.dateInterval(of: .weekOfYear, for: day)?.start else { continue }
            weeks[start, default: 0] += amount
        }
        guard let best = weeks.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key < $1.key }) else { return nil }
        let sealedDays = (0..<7).map { i -> Bool in
            guard let d = cal.date(byAdding: .day, value: i, to: best.key) else { return false }
            return ledger.isSealed(d)
        }
        return Week(start: best.key, kept: best.value, sealedDays: sealedDays)
    }
}
