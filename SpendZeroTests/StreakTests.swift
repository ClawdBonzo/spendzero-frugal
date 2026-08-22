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
