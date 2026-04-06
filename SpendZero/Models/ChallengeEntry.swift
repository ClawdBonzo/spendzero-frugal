import Foundation
import SwiftData

@Model
final class ChallengeEntry {
    var id: UUID
    var title: String
    var challengeDescription: String
    var durationDays: Int
    var startDate: Date?
    var isActive: Bool
    var isCompleted: Bool
    var completedDays: Int
    var category: ChallengeCategory
    var difficulty: ChallengeDifficulty
    var estimatedSavings: Double

    init(
        title: String,
        challengeDescription: String,
        durationDays: Int,
        category: ChallengeCategory,
        difficulty: ChallengeDifficulty,
        estimatedSavings: Double
    ) {
        self.id = UUID()
        self.title = title
        self.challengeDescription = challengeDescription
        self.durationDays = durationDays
        self.startDate = nil
        self.isActive = false
        self.isCompleted = false
        self.completedDays = 0
        self.category = category
        self.difficulty = difficulty
        self.estimatedSavings = estimatedSavings
    }
}

enum ChallengeCategory: String, Codable, CaseIterable {
    case noSpend = "No-Spend"
    case mealPrep = "Meal Prep"
    case subscription = "Subscription Audit"
    case impulse = "Impulse Control"
    case saving = "Saving Sprint"
    case minimalist = "Minimalist"
    case custom = "Custom"

    var icon: String {
        switch self {
        case .noSpend: return "nosign"
        case .mealPrep: return "fork.knife"
        case .subscription: return "list.clipboard.fill"
        case .impulse: return "bolt.slash.fill"
        case .saving: return "banknote.fill"
        case .minimalist: return "leaf.fill"
        case .custom: return "star.fill"
        }
    }
}

enum ChallengeDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case extreme = "Extreme"

    var color: String {
        switch self {
        case .easy: return "4CAF50"
        case .medium: return "FF9800"
        case .hard: return "FF5252"
        case .extreme: return "9C27B0"
        }
    }
}
