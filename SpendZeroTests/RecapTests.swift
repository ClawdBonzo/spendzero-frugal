import Testing
import Foundation
import SwiftData
@testable import SpendZero

struct RecapSchedulerTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func monthKeyIsYearAndMonth() {
        #expect(RecapScheduler.monthKey(date(2026, 9, 30), calendar: cal) == 202609)
        #expect(RecapScheduler.monthKey(date(2027, 1, 1, 0), calendar: cal) == 202701)
    }

    @Test func previousMonthIsPendingFromTheFirst() {
        let pending = RecapScheduler.pendingMonth(now: date(2026, 10, 1, 0), lastShownKey: nil, calendar: cal) { _ in 5 }
        #expect(pending == date(2026, 9, 1, 0))
        let later = RecapScheduler.pendingMonth(now: date(2026, 10, 23), lastShownKey: nil, calendar: cal) { _ in 5 }
        #expect(later == date(2026, 9, 1, 0))
    }

    @Test func intervalPassedToLoggedDaysIsThePreviousMonth() {
        var seen: DateInterval?
        _ = RecapScheduler.pendingMonth(now: date(2026, 3, 2), lastShownKey: nil, calendar: cal) { seen = $0; return 3 }
        #expect(seen?.start == date(2026, 2, 1, 0))
        #expect(seen?.end == date(2026, 3, 1, 0))
    }

    @Test func requiresThreeLoggedDays() {
        #expect(RecapScheduler.pendingMonth(now: date(2026, 10, 3), lastShownKey: nil, calendar: cal) { _ in 2 } == nil)
        #expect(RecapScheduler.pendingMonth(now: date(2026, 10, 3), lastShownKey: nil, calendar: cal) { _ in 3 } != nil)
    }

    @Test func onlyOncePerMonth() {
        #expect(RecapScheduler.pendingMonth(now: date(2026, 10, 3), lastShownKey: 202609, calendar: cal) { _ in 9 } == nil)
        #expect(RecapScheduler.pendingMonth(now: date(2026, 10, 3), lastShownKey: 202608, calendar: cal) { _ in 9 } != nil)
        // Crossing the year boundary.
        #expect(RecapScheduler.pendingMonth(now: date(2027, 1, 2), lastShownKey: 202611, calendar: cal) { _ in 9 } == date(2026, 12, 1, 0))
        #expect(RecapScheduler.pendingMonth(now: date(2027, 1, 2), lastShownKey: 202612, calendar: cal) { _ in 9 } == nil)
    }

    @Test func markShownPersistsAndNeverMovesBackwards() throws {
        let suite = "RecapSchedulerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        RecapScheduler.markShown(month: date(2026, 9, 1), defaults: defaults, calendar: cal)
        #expect(defaults.integer(forKey: RecapScheduler.lastShownKey) == 202609)
        RecapScheduler.markShown(month: date(2026, 7, 1), defaults: defaults, calendar: cal)
        #expect(defaults.integer(forKey: RecapScheduler.lastShownKey) == 202609)
    }

    @MainActor
    @Test func contextVariantCountsLoggedDaysAndHonoursDefaults() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SpendZeroSchemaV1.self),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let ctx = container.mainContext
        let suite = "RecapSchedulerTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 9))!
        for d in [2, 5] { ctx.insert(DailyRecord(date: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: d))!)) }
        #expect(RecapScheduler.pendingMonth(now: now, context: ctx, defaults: defaults) == nil)
        ctx.insert(DailyRecord(date: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 30))!, isNoSpendDay: false))
        let month = try #require(RecapScheduler.pendingMonth(now: now, context: ctx, defaults: defaults))
        RecapScheduler.markShown(month: month, defaults: defaults)
        #expect(RecapScheduler.pendingMonth(now: now, context: ctx, defaults: defaults) == nil)
    }
}

struct RecapBuilderTests {
    private let cal = Calendar.current
    private func sep(_ d: Int, _ h: Int = 0) -> Date { cal.date(from: DateComponents(year: 2026, month: 9, day: d, hour: h))! }

    private func day(_ d: Int, sealed: Bool, resisted: Int = 0, saved: Double = 0) -> RecapBuilder.DayInput {
        .init(date: sep(d), isNoSpendDay: sealed, totalSaved: saved, impulsesResisted: resisted)
    }

    @Test func aggregatesTheCalendarMonthOnly() {
        let records = [day(1, sealed: true), day(2, sealed: true), day(3, sealed: false),
                       day(4, sealed: true), day(5, sealed: true), day(6, sealed: true), day(30, sealed: true),
                       .init(date: cal.date(from: DateComponents(year: 2026, month: 8, day: 31))!, isNoSpendDay: true),
                       .init(date: cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!, isNoSpendDay: true)]
        let r = RecapBuilder.build(month: sep(15), records: records, urges: [], savings: [], level: nil,
                                   recordsAfterMonth: [], calendar: cal)
        #expect(r.month == sep(1))
        #expect(r.days.count == 30)
        #expect(r.noSpendDays == 6)
        #expect(r.loggedDays == 7)
        #expect(r.days[2] == .spent)
        #expect(r.days[6] == .unlogged)
        #expect(r.bestStreak == 3)
        #expect(r.bestStreakRange == 3...5)
    }

    @Test func spentWinsOverDuplicateSealedRow() {
        let r = RecapBuilder.build(month: sep(1), records: [day(7, sealed: true), day(7, sealed: false)], urges: [], savings: [],
                                   level: nil, recordsAfterMonth: [], calendar: cal)
        #expect(r.days[6] == .spent)
        #expect(r.bestStreak == 0)
        #expect(r.bestStreakRange == nil)
    }

    @Test func moneyKeptComesFromTheSavingsLedger() {
        let savings: [RecapBuilder.SavingInput] = [
            .init(date: sep(2, 10), amount: 40, source: .noSpendDay),
            .init(date: sep(3, 10), amount: 40, source: .noSpendDay),
            .init(date: sep(9, 10), amount: 130, source: .impulseResisted),
            .init(date: cal.date(from: DateComponents(year: 2026, month: 10, day: 2))!, amount: 999, source: .manual),
        ]
        let r = RecapBuilder.build(month: sep(1), records: [day(2, sealed: true, saved: 5)], urges: [], savings: savings,
                                   level: nil, recordsAfterMonth: [], calendar: cal)
        #expect(r.moneyKept == 210)
        #expect(r.keptBySource.map(\.source) == [.impulseResisted, .noSpendDay])
        #expect(r.keptBySource.first?.amount == 130)

        // Older data without ledger rows falls back to per-day totals.
        let legacy = RecapBuilder.build(month: sep(1), records: [day(2, sealed: true, saved: 25), day(3, sealed: true, saved: 15)],
                                        urges: [], savings: [], level: nil, recordsAfterMonth: [], calendar: cal)
        #expect(legacy.moneyKept == 40)
    }

    @Test func urgesCountResistedOnlyAndRankCategories() {
        let urges: [RecapBuilder.UrgeInput] = [
            .init(date: sep(2, 9), item: "Latte", cost: 6, category: .coffee, resisted: true),
            .init(date: sep(3, 9), item: "Latte", cost: 6, category: .coffee, resisted: true),
            .init(date: sep(4, 9), item: "Sneakers", cost: 130, category: .clothing, resisted: true),
            .init(date: sep(5, 9), item: "Pizza", cost: 30, category: .delivery, resisted: false),
            .init(date: cal.date(from: DateComponents(year: 2026, month: 10, day: 2))!, item: "TV", cost: 900, category: .electronics, resisted: true),
        ]
        let r = RecapBuilder.build(month: sep(1), records: [], urges: urges, savings: [], level: nil,
                                   recordsAfterMonth: [], calendar: cal)
        #expect(r.urgesBeaten == 3)
        #expect(r.topCategories.map(\.category) == [.coffee, .clothing])
        #expect(r.topCategories.first?.count == 2)
        #expect(r.biggestUrge == MonthRecap.TopUrge(item: "Sneakers", cost: 130))

        // Quick-tap counters on the day record count too when they exceed the detailed log.
        let counters = RecapBuilder.build(month: sep(1), records: [day(2, sealed: true, resisted: 4), day(3, sealed: true, resisted: 1)],
                                          urges: urges, savings: [], level: nil, recordsAfterMonth: [], calendar: cal)
        #expect(counters.urgesBeaten == 5)
    }

    @Test func levelMathRoundTrips() {
        #expect(LevelMath.level(forCumulativeXP: 0) == 1)
        let toFive = LevelMath.cumulativeXP(level: 5, xpIntoLevel: 0)
        #expect(LevelMath.level(forCumulativeXP: toFive) == 5)
        #expect(LevelMath.level(forCumulativeXP: toFive - 1) == 4)
        #expect(LevelMath.level(forCumulativeXP: .max / 2) == GameProfile.maxLevel)
        #expect(LevelMath.estimatedXP(.init(date: .now, isNoSpendDay: true, impulsesResisted: 2, winsAwarded: 1)) == 160)
    }

    @Test func levelsAreRewoundFromTodaysProfile() {
        // 20 sealed days in September (2,000 XP) and 5 in October (500 XP) on top of a level-8 profile.
        let sept = (1...20).map { day($0, sealed: true) }
        let oct = (1...5).map { RecapBuilder.DayInput(date: cal.date(from: DateComponents(year: 2026, month: 10, day: $0))!, isNoSpendDay: true) }
        let level = RecapBuilder.LevelInput(currentLevel: 8, currentXP: 100, seed: 1)
        let r = RecapBuilder.build(month: sep(1), records: sept, urges: [], savings: [], level: level,
                                   recordsAfterMonth: oct, calendar: cal)
        let now = LevelMath.cumulativeXP(level: 8, xpIntoLevel: 100)
        #expect(r.levelEnd == LevelMath.level(forCumulativeXP: now - 500))
        #expect(r.levelStart == LevelMath.level(forCumulativeXP: now - 2_500))
        #expect(r.levelsGained == r.levelEnd - r.levelStart)
        #expect(r.levelsGained >= 1)
        #expect(r.levelEnd <= 8)
    }

    @Test func noGameProfileMeansLevelOne() {
        let r = RecapBuilder.build(month: sep(1), records: [day(1, sealed: true)], urges: [], savings: [], level: nil,
                                   recordsAfterMonth: [], calendar: cal)
        #expect(r.levelStart == 1 && r.levelEnd == 1 && r.levelsGained == 0)
    }

    @MainActor
    @Test func loadReadsSwiftData() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: SpendZeroSchemaV1.self),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let ctx = container.mainContext
        for d in 1...4 { ctx.insert(DailyRecord(date: sep(d), isNoSpendDay: d != 3)) }
        let urge = ImpulseLog(item: "Headphones", estimatedCost: 199, category: .electronics, wasResisted: true)
        urge.date = sep(2, 15)
        ctx.insert(urge)
        let missed = ImpulseLog(item: "Fries", estimatedCost: 5, category: .snacks, wasResisted: false)
        missed.date = sep(3, 15)
        ctx.insert(missed)
        ctx.insert(SavingsEntry(amount: 25, date: sep(1, 20), source: .noSpendDay))
        ctx.insert(SavingsEntry(amount: 199, date: sep(2, 15), source: .impulseResisted))
        try ctx.save()

        let r = RecapBuilder.load(month: sep(10), context: ctx, now: cal.date(from: DateComponents(year: 2026, month: 10, day: 3))!)
        #expect(r.noSpendDays == 3)
        #expect(r.loggedDays == 4)
        #expect(r.bestStreak == 2)
        #expect(r.moneyKept == 224)
        #expect(r.urgesBeaten == 1)
        #expect(r.topCategories.map(\.category) == [.electronics])
    }

    @Test func demoIsConsistent() {
        let d = MonthRecap.demo()
        #expect(d.noSpendDays == d.days.filter { $0 == .sealed }.count)
        #expect(d.bestStreak == d.bestStreakRange?.count)
        #expect(d.levelsGained == 2)
    }
}
