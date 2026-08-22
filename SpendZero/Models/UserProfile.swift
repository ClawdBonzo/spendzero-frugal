import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var createdAt: Date
    var dailyBudget: Double
    var monthlyIncome: Double
    var challengeDays: Int
    var spendingLevel: SpendingLevel
    var leakCategories: [String]
    var totalSaved: Double
    var currentStreak: Int
    var longestStreak: Int
    var trialStartDate: Date?
    var lastPaywallShownDate: Date?
    /// Start-of-day of the most recent logged no-spend day. Used to detect a lapsed
    /// streak when the user skips a day. nil means no day has been logged yet.
    var lastNoSpendDate: Date? = nil
    /// Streak freezes protect the streak when a day is missed (one freeze = one day).
    /// Earned at streak milestones; auto-consumed before the streak is allowed to lapse.
    var streakFreezes: Int = 0
    @Relationship(deleteRule: .cascade) var gameProfile: GameProfile?

    // MARK: - Full-access window
    //
    // A device-local window of full access after onboarding (distinct from any StoreKit intro
    // offer). Measured in calendar days so DST and late-night starts don't shift the boundary.

    static let trialDurationDays = 3

    /// Which day of the window the user is on (1-indexed); 0 if not started.
    func trialDayNumber(asOf now: Date = Date()) -> Int {
        guard let start = trialStartDate else { return 0 }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: now)).day ?? 0
        return max(1, days + 1)
    }
    var trialDayNumber: Int { trialDayNumber() }

    var isTrialActive: Bool {
        guard hasStartedTrial else { return false }
        return trialDayNumber <= Self.trialDurationDays
    }

    var hasStartedTrial: Bool { trialStartDate != nil }
    var isTrialExpired: Bool { hasStartedTrial && !isTrialActive }

    /// Calendar days left including today (0 once expired).
    var trialDaysRemaining: Int {
        guard hasStartedTrial else { return Self.trialDurationDays }
        return max(0, Self.trialDurationDays - trialDayNumber + 1)
    }

    /// Whether we should show a strategic paywall nudge today (day 2+, once per calendar day).
    var shouldShowPaywallNudge: Bool {
        guard hasStartedTrial else { return false }
        if isTrialExpired { return true }
        guard trialDayNumber >= 2 else { return false }
        if let lastShown = lastPaywallShownDate, Calendar.current.isDateInToday(lastShown) {
            return false
        }
        return true
    }

    // MARK: - Streak Maintenance

    /// Outcome of reconciling the streak against the calendar.
    enum StreakOutcome: Equatable {
        case intact                 // logged today or yesterday — nothing to do
        case frozen(daysUsed: Int)  // a missed day (or days) was covered by freezes
        case lapsed(lostStreak: Int) // streak broke (no freezes left)
    }

    /// Whether today's no-spend day has already been logged.
    func hasLoggedToday(asOf now: Date = Date()) -> Bool {
        guard let last = lastNoSpendDate else { return false }
        return Calendar.current.isDate(last, inSameDayAs: now)
    }

    /// Call on app open (and before logging) to break the streak if a day was missed.
    /// Spends streak freezes to cover gaps before letting the streak lapse.
    @discardableResult
    func reconcileStreak(asOf now: Date = Date()) -> StreakOutcome {
        let cal = Calendar.current
        guard currentStreak > 0, let last = lastNoSpendDate else { return .intact }

        let lastDay = cal.startOfDay(for: last)
        let today = cal.startOfDay(for: now)
        let daysSince = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0

        // 0 = logged today, 1 = logged yesterday and still alive today → no gap yet.
        guard daysSince >= 2 else { return .intact }

        let missed = daysSince - 1   // fully-skipped days between last log and today
        if streakFreezes >= missed {
            streakFreezes -= missed
            // Freeze covers the gap: treat the streak as maintained through yesterday,
            // so today still needs a fresh log to continue.
            lastNoSpendDate = cal.date(byAdding: .day, value: -1, to: today)
            return .frozen(daysUsed: missed)
        } else {
            let lost = currentStreak
            currentStreak = 0
            lastNoSpendDate = nil
            return .lapsed(lostStreak: lost)
        }
    }

    /// Register a fresh no-spend day for today, advancing the streak. Reconciles first
    /// so a gap is handled correctly even if the app stayed open across midnight.
    /// Returns the new streak length, or nil if today was already logged.
    @discardableResult
    func registerNoSpendDay(asOf now: Date = Date()) -> Int? {
        reconcileStreak(asOf: now)
        guard !hasLoggedToday(asOf: now) else { return nil }
        currentStreak += 1
        if currentStreak > longestStreak { longestStreak = currentStreak }
        lastNoSpendDate = Calendar.current.startOfDay(for: now)
        return currentStreak
    }

    init(
        displayName: String = "",
        dailyBudget: Double = 50.0,
        monthlyIncome: Double = 0,
        challengeDays: Int = 30,
        spendingLevel: SpendingLevel = .moderate,
        leakCategories: [String] = []
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.createdAt = Date()
        self.dailyBudget = dailyBudget
        self.monthlyIncome = monthlyIncome
        self.challengeDays = challengeDays
        self.spendingLevel = spendingLevel
        self.leakCategories = leakCategories
        self.totalSaved = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.trialStartDate = nil
        self.lastPaywallShownDate = nil
    }
}

enum SpendingLevel: String, Codable, CaseIterable {
    case minimal = "Minimal Spender"
    case moderate = "Moderate Spender"
    case heavy = "Heavy Spender"
    case impulsive = "Impulse Buyer"

    var dailyEstimate: Double {
        switch self {
        case .minimal: return 20
        case .moderate: return 50
        case .heavy: return 100
        case .impulsive: return 150
        }
    }

    /// SF Symbol name representing the spending level
    var icon: String {
        switch self {
        case .minimal:   return "leaf.fill"
        case .moderate:  return "dollarsign.circle.fill"
        case .heavy:     return "flame.fill"
        case .impulsive: return "bolt.fill"
        }
    }

    /// Tint color for the icon
    var iconColorHex: String {
        switch self {
        case .minimal:   return "00C853"   // green
        case .moderate:  return "FFB300"   // gold
        case .heavy:     return "FF6B35"   // orange
        case .impulsive: return "F44336"   // red
        }
    }
}
