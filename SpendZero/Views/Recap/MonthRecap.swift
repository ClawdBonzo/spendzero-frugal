import Foundation
import SwiftData

/// Everything the Monthly Recap story shows, computed once for one calendar month.
/// Value type so the cards, the share image and the tests all read the same numbers.
struct MonthRecap: Equatable, Identifiable {
    enum DayState: Equatable { case sealed, spent, unlogged }

    struct CategoryCount: Equatable, Identifiable {
        let category: SpendCategory
        let count: Int
        var id: String { category.rawValue }
    }

    struct SourceAmount: Equatable, Identifiable {
        let source: SavingsSource
        let amount: Double
        var id: String { source.rawValue }
    }

    struct TopUrge: Equatable {
        let item: String
        let cost: Double
    }

    /// First instant of the month in the current calendar.
    let month: Date
    /// One entry per day of the month; index 0 is the 1st.
    let days: [DayState]
    let moneyKept: Double
    /// Savings split by where they came from, largest first.
    let keptBySource: [SourceAmount]
    let bestStreak: Int
    /// Day indices (0-based) of the longest sealed run, if any.
    let bestStreakRange: ClosedRange<Int>?
    let urgesBeaten: Int
    /// Most-resisted categories, most first (at most four).
    let topCategories: [CategoryCount]
    let biggestUrge: TopUrge?
    let levelStart: Int
    let levelEnd: Int
    let treeSeed: UInt64

    var id: Date { month }
    var noSpendDays: Int { days.filter { $0 == .sealed }.count }
    var loggedDays: Int { days.filter { $0 != .unlogged }.count }
    var levelsGained: Int { max(0, levelEnd - levelStart) }

    /// Locale-aware full month name ("September", "septembre", "9月").
    var monthName: String { month.formatted(.dateTime.month(.wide)) }

    /// Wealth-tree growth (0…1) at a level, matching MoneyTreeView's curve.
    static func treeGrowth(level: Int) -> Double { min(1, max(0.1, Double(level - 1) / 24)) }
}

// MARK: - Building from data

/// Pure aggregation over plain inputs (tested), plus a loader that reads SwiftData.
enum RecapBuilder {
    struct DayInput {
        var date: Date
        var isNoSpendDay: Bool
        var totalSaved: Double = 0
        var impulsesResisted: Int = 0
        var winsAwarded: Int = 0
    }

    struct UrgeInput {
        var date: Date
        var item: String
        var cost: Double
        var category: SpendCategory
        var resisted: Bool
    }

    struct SavingInput {
        var date: Date
        var amount: Double
        var source: SavingsSource
    }

    struct LevelInput {
        var currentLevel: Int
        var currentXP: Int
        var seed: UInt64
    }

    static func monthInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 86_400 * 30)
    }

    /// - Parameters:
    ///   - records: daily records in (or around) the month; out-of-month rows are ignored.
    ///   - recordsAfterMonth: records from the month's end up to now, used to rewind the level.
    static func build(month: Date, records: [DayInput], urges: [UrgeInput], savings: [SavingInput],
                      level: LevelInput?, recordsAfterMonth: [DayInput], calendar: Calendar = .current) -> MonthRecap {
        let interval = monthInterval(containing: month, calendar: calendar)
        let dayCount = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        func inMonth(_ d: Date) -> Bool { d >= interval.start && d < interval.end }

        // Day states: a record marked no-spend seals the day; any other record means it was spent.
        var days = Array(repeating: MonthRecap.DayState.unlogged, count: dayCount)
        let monthRecords = records.filter { inMonth($0.date) }
        for r in monthRecords {
            let i = calendar.component(.day, from: r.date) - 1
            guard days.indices.contains(i) else { continue }
            // Duplicate rows for one day: spent wins, matching ProgressEngine's dedupe.
            if r.isNoSpendDay {
                if days[i] == .unlogged { days[i] = .sealed }
            } else {
                days[i] = .spent
            }
        }

        // Longest run of sealed days inside the month.
        var best = 0, bestRange: ClosedRange<Int>?
        var runStart = 0, run = 0
        for (i, s) in days.enumerated() {
            if s == .sealed {
                if run == 0 { runStart = i }
                run += 1
                if run > best { best = run; bestRange = runStart...i }
            } else {
                run = 0
            }
        }

        // Money kept: the savings ledger, falling back to per-day totals for older data.
        let monthSavings = savings.filter { inMonth($0.date) && $0.amount > 0 }
        var bySource: [SavingsSource: Double] = [:]
        for s in monthSavings { bySource[s.source, default: 0] += s.amount }
        var kept = monthSavings.reduce(0) { $0 + $1.amount }
        if kept == 0 { kept = monthRecords.reduce(0) { $0 + max(0, $1.totalSaved) } }
        let keptBySource = bySource
            .map { MonthRecap.SourceAmount(source: $0.key, amount: $0.value) }
            .sorted { $0.amount != $1.amount ? $0.amount > $1.amount : $0.source.rawValue < $1.source.rawValue }

        // Urges: the impulse log is the detailed source; day counters cover quick taps.
        let resisted = urges.filter { inMonth($0.date) && $0.resisted }
        let counterTotal = monthRecords.reduce(0) { $0 + max(0, $1.impulsesResisted) }
        let urgesBeaten = max(resisted.count, counterTotal)
        var byCategory: [SpendCategory: Int] = [:]
        for u in resisted { byCategory[u.category, default: 0] += 1 }
        let order = SpendCategory.allCases
        let topCategories = byCategory
            .map { MonthRecap.CategoryCount(category: $0.key, count: $0.value) }
            .sorted {
                $0.count != $1.count ? $0.count > $1.count
                    : (order.firstIndex(of: $0.category) ?? 0) < (order.firstIndex(of: $1.category) ?? 0)
            }
            .prefix(4)
        let biggest = resisted.max { $0.cost < $1.cost }.map { MonthRecap.TopUrge(item: $0.item, cost: $0.cost) }

        // Levels: XP isn't stored per day, so rewind today's cumulative XP by the base XP the
        // logged activity earned (no multipliers or quest bonuses — a conservative estimate).
        var levelStart = 1, levelEnd = 1
        if let level {
            let now = LevelMath.cumulativeXP(level: level.currentLevel, xpIntoLevel: level.currentXP)
            let after = recordsAfterMonth.filter { $0.date >= interval.end }.reduce(0) { $0 + LevelMath.estimatedXP($1) }
            let during = monthRecords.reduce(0) { $0 + LevelMath.estimatedXP($1) }
            levelEnd = min(level.currentLevel, LevelMath.level(forCumulativeXP: max(0, now - after)))
            levelStart = min(levelEnd, LevelMath.level(forCumulativeXP: max(0, now - after - during)))
        }

        return MonthRecap(month: interval.start, days: days, moneyKept: kept, keptBySource: keptBySource,
                          bestStreak: best, bestStreakRange: bestRange, urgesBeaten: urgesBeaten,
                          topCategories: Array(topCategories), biggestUrge: biggest,
                          levelStart: levelStart, levelEnd: levelEnd, treeSeed: level?.seed ?? 0x5EED)
    }

    /// Reads one month (plus the activity since, for the level rewind) from SwiftData.
    @MainActor
    static func load(month: Date, context: ModelContext, now: Date = Date(), calendar: Calendar = .current) -> MonthRecap {
        let interval = monthInterval(containing: month, calendar: calendar)
        let start = interval.start, end = interval.end
        let recordRows = (try? context.fetch(FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.date >= start }))) ?? []
        let dayInputs = recordRows.map {
            DayInput(date: $0.date, isNoSpendDay: $0.isNoSpendDay, totalSaved: $0.totalSaved,
                     impulsesResisted: $0.impulsesResisted, winsAwarded: $0.xpAwardedWins.count)
        }
        // Enums can't be filtered in #Predicate, so filter `wasResisted`/category in memory.
        let urgeRows = (try? context.fetch(FetchDescriptor<ImpulseLog>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let savingRows = (try? context.fetch(FetchDescriptor<SavingsEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let game = (try? context.fetch(FetchDescriptor<GameProfile>()))?.first

        return build(
            month: start,
            records: dayInputs.filter { $0.date < end },
            urges: urgeRows.map { UrgeInput(date: $0.date, item: $0.item, cost: $0.estimatedCost, category: $0.category, resisted: $0.wasResisted) },
            savings: savingRows.map { SavingInput(date: $0.date, amount: $0.amount, source: $0.source) },
            level: game.map { LevelInput(currentLevel: $0.currentLevel, currentXP: $0.currentXP, seed: $0.id.seed64) },
            recordsAfterMonth: dayInputs.filter { $0.date >= end && $0.date <= now },
            calendar: calendar)
    }
}

/// Mirrors GameProfile's level curve without needing a model instance.
enum LevelMath {
    static func threshold(level: Int) -> Int { Int(300 * pow(1.2, Double(level))) }

    static func cumulativeXP(level: Int, xpIntoLevel: Int) -> Int {
        guard level > 1 else { return max(0, xpIntoLevel) }
        return (1..<min(level, GameProfile.maxLevel)).reduce(0) { $0 + threshold(level: $1) } + max(0, xpIntoLevel)
    }

    static func level(forCumulativeXP xp: Int) -> Int {
        var remaining = xp, level = 1
        while level < GameProfile.maxLevel, remaining >= threshold(level: level) {
            remaining -= threshold(level: level)
            level += 1
        }
        return level
    }

    static func estimatedXP(_ day: RecapBuilder.DayInput) -> Int {
        (day.isNoSpendDay ? XPAction.noSpendDay.baseXP : 0)
            + max(0, day.impulsesResisted) * XPAction.impulseResisted.baseXP
            + max(0, day.winsAwarded) * XPAction.dailyWin.baseXP
    }
}

// MARK: - Demo

extension MonthRecap {
    /// Deterministic, aspirational recap of last month for screenshots and previews.
    static func demo(now: Date = Date(), calendar: Calendar = .current) -> MonthRecap {
        let thisMonth = RecapBuilder.monthInterval(containing: now, calendar: calendar).start
        let month = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? thisMonth
        let count = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        let spent: Set<Int> = [3, 4, 9, 25, 26]
        let unlogged: Set<Int> = [30]
        let days: [DayState] = (1...count).map { spent.contains($0) ? .spent : unlogged.contains($0) ? .unlogged : .sealed }
        return MonthRecap(
            month: month, days: days, moneyKept: 880,
            keptBySource: [.init(source: .noSpendDay, amount: 480), .init(source: .impulseResisted, amount: 300),
                           .init(source: .subscriptionCanceled, amount: 100)],
            bestStreak: 15, bestStreakRange: 9...23, urgesBeaten: 17,
            topCategories: [.init(category: .delivery, count: 6), .init(category: .coffee, count: 5),
                            .init(category: .clothing, count: 4), .init(category: .electronics, count: 2)],
            biggestUrge: TopUrge(item: "Espresso machine", cost: 249),
            levelStart: 11, levelEnd: 13, treeSeed: 0xC0FFEE)
    }
}
