import Testing
import Foundation
@testable import SpendZero

@MainActor
struct StreakTests {
    private func profile(streak: Int, lastLoggedDaysAgo: Int?, freezes: Int = 0) -> UserProfile {
        let p = UserProfile(displayName: "T")
        p.currentStreak = streak
        p.longestStreak = streak
        p.streakFreezes = freezes
        if let d = lastLoggedDaysAgo {
            p.lastNoSpendDate = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -d, to: Date())!)
        }
        return p
    }

    @Test func loggedYesterdayIsIntact() {
        let p = profile(streak: 5, lastLoggedDaysAgo: 1)
        #expect(p.reconcileStreak() == .intact)
        #expect(p.currentStreak == 5)
    }

    @Test func missedOneDayWithoutFreezeLapses() {
        let p = profile(streak: 5, lastLoggedDaysAgo: 2)
        #expect(p.reconcileStreak() == .lapsed(lostStreak: 5))
        #expect(p.currentStreak == 0)
    }

    @Test func missedOneDayWithFreezeIsFrozen() {
        let p = profile(streak: 5, lastLoggedDaysAgo: 2, freezes: 1)
        #expect(p.reconcileStreak() == .frozen(daysUsed: 1))
        #expect(p.currentStreak == 5)
        #expect(p.streakFreezes == 0)
        #expect(p.hasLoggedToday() == false)
    }

    @Test func registerTwiceSameDayOnlyCountsOnce() {
        let p = profile(streak: 0, lastLoggedDaysAgo: nil)
        #expect(p.registerNoSpendDay() == 1)
        #expect(p.registerNoSpendDay() == nil)
        #expect(p.currentStreak == 1)
    }
}

@MainActor
struct TrialWindowTests {
    @Test func threeCalendarDaysInclusive() {
        let cal = Calendar.current
        let p = UserProfile(displayName: "T")
        // Started late on a day: day 1 is that day, day 3 is two days later, expired on day 4.
        let start = cal.date(bySettingHour: 23, minute: 30, second: 0, of: cal.startOfDay(for: Date()))!
        p.trialStartDate = start
        #expect(p.trialDayNumber(asOf: start) == 1)
        let day3 = cal.date(byAdding: .day, value: 2, to: start)!
        #expect(p.trialDayNumber(asOf: cal.startOfDay(for: day3)) == 3)
        let day4 = cal.date(byAdding: .day, value: 3, to: start)!
        #expect(p.trialDayNumber(asOf: cal.startOfDay(for: day4)) == 4)
    }
}
