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
