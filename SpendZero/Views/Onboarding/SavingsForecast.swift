import Foundation

/// A 12-month savings estimate built only from the user's own onboarding answers:
/// goal no-spend days per month × what they usually spend on extras each day × 12.
/// Nothing is projected, compounded or invented — the curve is a straight accumulation.
struct SavingsForecast: Equatable {
    static let months = 12
    /// Months that get a gold coin on the chart (quarterly; the last is the year-one total).
    static let milestones = [3, 6, 9, 12]

    /// What a no-spend day keeps: the user's usual daily spend on extras.
    let dailyExtras: Double
    /// No-spend days per month: the user's chosen challenge length, capped at a realistic month.
    /// A 30-day pick would otherwise assume a whole year without a single non-essential purchase.
    let goalDaysPerMonth: Int
    static let realisticDaysPerMonth = 20
    let start: Date

    init(dailyExtras: Double, challengeDays: Int, start: Date = .now) {
        self.dailyExtras = max(0, dailyExtras)
        self.goalDaysPerMonth = min(max(challengeDays, 0), Self.realisticDaysPerMonth)
        self.start = start
    }

    init(level: SpendingLevel, challengeDays: Int, start: Date = .now) {
        self.init(dailyExtras: level.dailyEstimate, challengeDays: challengeDays, start: start)
    }

    /// Uses the amount the app actually credits per no-spend day (`dailyBudget`, set from the
    /// spending quiz and editable in Settings). Nil when the answers can't produce an estimate.
    init?(profile: UserProfile, start: Date = .now) {
        let daily = profile.dailyBudget > 0 ? profile.dailyBudget : profile.spendingLevel.dailyEstimate
        self.init(dailyExtras: daily, challengeDays: profile.challengeDays, start: start)
        guard total > 0 else { return nil }
    }

    var monthly: Double { dailyExtras * Double(goalDaysPerMonth) }
    var total: Double { monthly * Double(Self.months) }

    /// Running total after `month` months (0…12).
    func cumulative(afterMonth month: Int) -> Double { monthly * Double(min(max(month, 0), Self.months)) }

    func date(afterMonths month: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: month, to: start) ?? start
    }

    var endDate: Date { date(afterMonths: Self.months) }
}

extension Double {
    /// Short currency for tight spaces: "$840", "$3.4K", "$18K".
    var compactCurrency: String {
        let code = Locale.current.currency?.identifier ?? "USD"
        if abs(self) < 10_000 { return currencyFormatted }
        return formatted(.currency(code: code).notation(.compactName).precision(.significantDigits(1...3)))
    }
}
