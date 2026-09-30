import Testing
import Foundation
import SwiftData
@testable import SpendZero

@MainActor
struct SeasonalChallengesTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func blackFridayIsDayAfterFourthThursday() {
        let bf2026 = SeasonalChallenges.blackFridayDate(year: 2026, calendar: cal)!
        #expect(cal.dateComponents([.month, .day], from: bf2026) == DateComponents(month: 11, day: 27))
        let bf2027 = SeasonalChallenges.blackFridayDate(year: 2027, calendar: cal)!
        #expect(cal.dateComponents([.month, .day], from: bf2027) == DateComponents(month: 11, day: 26))
    }

    @Test func windowsOpenAndCloseOnTheRightDays() {
        let bf = SeasonalChallenges.blackFriday
        #expect(SeasonalChallenges.window(of: bf, containing: date(2026, 11, 12), calendar: cal) == nil)
        #expect(SeasonalChallenges.window(of: bf, containing: date(2026, 11, 13), calendar: cal) != nil)
        #expect(SeasonalChallenges.window(of: bf, containing: date(2026, 11, 30), calendar: cal) != nil)
        #expect(SeasonalChallenges.window(of: bf, containing: date(2026, 12, 1), calendar: cal) == nil)

        let jan = SeasonalChallenges.january
        #expect(SeasonalChallenges.window(of: jan, containing: date(2026, 12, 17), calendar: cal) == nil)
        #expect(SeasonalChallenges.window(of: jan, containing: date(2026, 12, 18), calendar: cal) != nil)
        #expect(SeasonalChallenges.window(of: jan, containing: date(2027, 1, 31), calendar: cal) != nil)
        #expect(SeasonalChallenges.window(of: jan, containing: date(2027, 2, 1), calendar: cal) == nil)

        let twelve = SeasonalChallenges.twelveDays
        #expect(SeasonalChallenges.window(of: twelve, containing: date(2026, 12, 24), calendar: cal) != nil)
        #expect(SeasonalChallenges.window(of: twelve, containing: date(2026, 12, 25), calendar: cal) == nil)
    }

    @Test func syncAddsInWindowAndRemovesUntouchedOutOfWindow() throws {
        let schema = Schema(versionedSchema: SpendZeroSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let ctx = container.mainContext
        let fetch = { try ctx.fetch(FetchDescriptor<ChallengeEntry>()) }

        ProgressEngine.shared.syncSeasonalChallenges(try fetch(), context: ctx, now: date(2026, 11, 20))
        #expect(try fetch().map(\.title) == ["Black Friday No-Buy Weekend"])

        // Out of window and never started: removed.
        ProgressEngine.shared.syncSeasonalChallenges(try fetch(), context: ctx, now: date(2026, 12, 5))
        #expect(try fetch().map(\.title) == ["12 Days of No-Spend"])

        // Started challenges survive their window closing.
        let twelve = try #require(try fetch().first)
        twelve.isActive = true
        twelve.startDate = date(2026, 12, 13)
        ProgressEngine.shared.syncSeasonalChallenges(try fetch(), context: ctx, now: date(2026, 12, 28))
        #expect(Set(try fetch().map(\.title)) == ["12 Days of No-Spend", "No-Spend January"])
    }

    @Test func lastSeasonsCompletedCopyIsResetForTheNewSeason() throws {
        let schema = Schema(versionedSchema: SpendZeroSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let ctx = container.mainContext
        let seasonal = SeasonalChallenges.blackFriday
        let old = ChallengeEntry(title: seasonal.title, challengeDescription: seasonal.description,
                                 durationDays: 4, category: .noSpend, difficulty: .medium, estimatedSavings: 250)
        old.isCompleted = true
        old.completedDays = 4
        old.startDate = date(2026, 11, 27)
        ctx.insert(old)

        ProgressEngine.shared.syncSeasonalChallenges([old], context: ctx, now: date(2027, 11, 20))
        #expect(!old.isCompleted)
        #expect(old.completedDays == 0)
        #expect(old.startDate == nil)
    }

    @Test func deepLinksParse() {
        let router = DeepLinkRouter.shared
        #expect(router.handle(URL(string: "spendzero://challenge/no-spend-january")!))
        #expect(router.pendingChallengeKey == "no-spend-january")
        #expect(router.handle(URL(string: "spendzero://challenges")!))
        #expect(router.pendingChallengeKey == "")
        router.pendingChallengeKey = nil
        #expect(!router.handle(URL(string: "https://gwlabs.app/spendzero.html")!))
        #expect(!router.handle(URL(string: "spendzero://unknown")!))
        #expect(router.pendingChallengeKey == nil)
    }
}
