import Testing
import Foundation
@testable import SpendZero

struct ReviewPrompterTests {
    @Test func milestonesFireOnRealWins() {
        #expect(ReviewPrompter.candidateMilestones(totalNoSpendDays: 3, newStreak: 3, levelUp: nil, challengeCompleted: false) == ["nsd-3"])
        #expect(ReviewPrompter.candidateMilestones(totalNoSpendDays: 18, newStreak: 2, levelUp: nil, challengeCompleted: false) == ["nsd-18"])
        #expect(ReviewPrompter.candidateMilestones(totalNoSpendDays: 9, newStreak: 7, levelUp: nil, challengeCompleted: false) == ["streak-7"])
        #expect(ReviewPrompter.candidateMilestones(totalNoSpendDays: 9, newStreak: 1, levelUp: (4, 5), challengeCompleted: false) == ["level-5"])
        #expect(ReviewPrompter.candidateMilestones(totalNoSpendDays: 9, newStreak: 1, levelUp: (5, 6), challengeCompleted: false).isEmpty)
        #expect(ReviewPrompter.candidateMilestones(totalNoSpendDays: 4, newStreak: 1, levelUp: nil, challengeCompleted: true) == ["challenge"])
        #expect(ReviewPrompter.candidateMilestones(totalNoSpendDays: 2, newStreak: 2, levelUp: nil, challengeCompleted: false).isEmpty)
    }

    @Test func throttlesToThreePerYearAndThirtyDaysApart() {
        let now = Date()
        let cal = Calendar.current
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now)! }
        #expect(ReviewPrompter.isEligible(previousAsks: [], now: now))
        #expect(!ReviewPrompter.isEligible(previousAsks: [daysAgo(10)], now: now))
        #expect(ReviewPrompter.isEligible(previousAsks: [daysAgo(31)], now: now))
        #expect(!ReviewPrompter.isEligible(previousAsks: [daysAgo(300), daysAgo(200), daysAgo(100)], now: now))
        #expect(ReviewPrompter.isEligible(previousAsks: [daysAgo(400), daysAgo(200), daysAgo(100)], now: now))
    }

    @Test func streakMilestoneMath() {
        #expect(StreakMilestone.next(after: 0) == 3)
        #expect(StreakMilestone.next(after: 7) == 14)
        #expect(StreakMilestone.previous(atOrBelow: 23) == 14)
        #expect(StreakMilestone.next(after: 365) == nil)
        #expect(StreakMilestone.rewards(for: 14).count == 1)       // freeze only
        #expect(StreakMilestone.rewards(for: 30).count == 1)       // badge only (30 % 7 != 0)
        #expect(StreakMilestone.rewards(for: 7).count == 2)        // badge + freeze
    }
}
