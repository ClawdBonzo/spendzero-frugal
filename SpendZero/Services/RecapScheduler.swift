import Foundation
import SwiftData

/// Decides when last month's recap is ready: any time on or after the 1st of a new month, once
/// per month, and only when the user logged at least three days in that month.
/// State is a single "yyyymm" integer in UserDefaults — no SwiftData schema involvement.
enum RecapScheduler {
    static let lastShownKey = "monthlyRecap.lastShownMonth"
    static let minimumLoggedDays = 3

    /// The start of the month whose recap should be shown now, or nil.
    @MainActor
    static func pendingMonth(now: Date = Date(), context: ModelContext,
                             defaults: UserDefaults = .standard, calendar: Calendar = .current) -> Date? {
        pendingMonth(now: now, lastShownKey: defaults.object(forKey: lastShownKey) as? Int, calendar: calendar) { interval in
            let start = interval.start, end = interval.end
            return (try? context.fetchCount(FetchDescriptor<DailyRecord>(
                predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? 0
        }
    }

    /// Pure decision, injectable for tests.
    /// - Parameter loggedDays: number of logged days in the candidate month's interval.
    static func pendingMonth(now: Date, lastShownKey: Int?, calendar: Calendar = .current,
                             loggedDays: (DateInterval) -> Int) -> Date? {
        guard let thisMonth = calendar.dateInterval(of: .month, for: now)?.start,
              let previous = calendar.date(byAdding: .month, value: -1, to: thisMonth),
              let interval = calendar.dateInterval(of: .month, for: previous) else { return nil }
        let key = monthKey(previous, calendar: calendar)
        if let lastShownKey, lastShownKey >= key { return nil }
        guard loggedDays(interval) >= minimumLoggedDays else { return nil }
        return interval.start
    }

    /// Record that the recap for `month` has been presented, so it never shows again.
    static func markShown(month: Date, defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        let key = monthKey(month, calendar: calendar)
        let existing = defaults.object(forKey: lastShownKey) as? Int ?? 0
        defaults.set(max(existing, key), forKey: lastShownKey)
    }

    /// 2026-09 → 202609. Calendar-local, so time zones and DST never shift the month.
    static func monthKey(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month], from: date)
        return (c.year ?? 0) * 100 + (c.month ?? 0)
    }
}
