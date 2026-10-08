import Testing
import Foundation
@testable import SpendZero

struct SavingsForecastTests {
    @Test func totalIsGoalDaysTimesDailyExtrasTimesTwelve() {
        let f = SavingsForecast(dailyExtras: 20, challengeDays: 14)
        #expect(f.goalDaysPerMonth == 14)
        #expect(f.monthly == 280)
        #expect(f.total == 3360)
        #expect(f.cumulative(afterMonth: 6) == 1680)
    }

    @Test func longChallengesAreCappedAtARealisticMonth() {
        let f = SavingsForecast(dailyExtras: 40, challengeDays: 30)
        #expect(f.goalDaysPerMonth == SavingsForecast.realisticDaysPerMonth)
        #expect(f.total == 40 * 20 * 12)
    }

    @Test func negativeInputsNeverProduceANegativeForecast() {
        let f = SavingsForecast(dailyExtras: -5, challengeDays: -3)
        #expect(f.total == 0)
        #expect(f.cumulative(afterMonth: 99) == 0)
    }
}
