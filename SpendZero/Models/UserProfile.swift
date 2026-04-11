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
    var isPremium: Bool
    var trialStartDate: Date?
    var lastPaywallShownDate: Date?
    @Relationship(deleteRule: .cascade) var gameProfile: GameProfile?

    // MARK: - Trial Logic

    static let trialDurationDays = 3

    /// Whether the free trial is still active (within 3 days of start)
    var isTrialActive: Bool {
        guard let start = trialStartDate else { return false }
        let elapsed = Date().timeIntervalSince(start)
        return elapsed < Double(Self.trialDurationDays) * 86400
    }

    /// Whether trial has been started at all
    var hasStartedTrial: Bool { trialStartDate != nil }

    /// Whether the trial has expired (started but past 3 days)
    var isTrialExpired: Bool { hasStartedTrial && !isTrialActive }

    /// Whether user has full access (paid OR trial still active)
    var hasFullAccess: Bool { isPremium || isTrialActive }

    /// Days remaining in trial (0 if expired)
    var trialDaysRemaining: Int {
        guard let start = trialStartDate else { return Self.trialDurationDays }
        let elapsed = Date().timeIntervalSince(start) / 86400
        return max(0, Self.trialDurationDays - Int(ceil(elapsed)))
    }

    /// Whether we should show a strategic paywall nudge today
    var shouldShowPaywallNudge: Bool {
        guard hasStartedTrial, !isPremium else { return false }
        // Show on day 2 or day 3 of trial, or anytime after expiry
        if isTrialExpired { return true }
        let dayOfTrial = trialDayNumber
        guard dayOfTrial >= 2 else { return false }
        // Only show once per calendar day
        if let lastShown = lastPaywallShownDate,
           Calendar.current.isDateInToday(lastShown) {
            return false
        }
        return true
    }

    /// Which day of trial the user is on (1-indexed)
    var trialDayNumber: Int {
        guard let start = trialStartDate else { return 0 }
        return Int(Date().timeIntervalSince(start) / 86400) + 1
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
        self.isPremium = false
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

    var emoji: String {
        switch self {
        case .minimal: return "🌱"
        case .moderate: return "💰"
        case .heavy: return "🔥"
        case .impulsive: return "⚡"
        }
    }
}
