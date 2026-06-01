import Foundation
import SwiftData

/// Individual quest instance with tracking and progression
@Model
final class Quest {
    var id: UUID

    // MARK: - Quest Definition
    var title: String
    var details: String
    var type: QuestType
    var difficulty: QuestDifficulty

    // MARK: - XP & Rewards
    var baseXPReward: Int

    // MARK: - Progression
    var targetValue: Double
    var currentProgress: Double = 0
    var isCompleted: Bool = false

    // MARK: - Timing
    var createdDate: Date = Date()
    var completedDate: Date?
    var isDaily: Bool
    var expiresAt: Date

    init(
        title: String,
        details: String,
        type: QuestType,
        difficulty: QuestDifficulty,
        targetValue: Double,
        isDaily: Bool
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.type = type
        self.difficulty = difficulty
        self.baseXPReward = difficulty.baseXP
        self.targetValue = targetValue
        self.isDaily = isDaily

        // Set expiry based on daily/weekly
        let calendar = Calendar.current
        if isDaily {
            // Expires tomorrow at midnight
            self.expiresAt = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        } else {
            // Expires in 7 days at midnight
            self.expiresAt = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        }
    }

    /// Progress toward completing quest (0.0 to 1.0)
    var progressPercent: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, currentProgress / targetValue)
    }

    /// Mark quest as complete
    func markComplete() {
        self.isCompleted = true
        self.completedDate = Date()
        self.currentProgress = targetValue
    }

    /// Update progress toward quest goal
    func addProgress(_ amount: Double) {
        guard !isCompleted else { return }
        self.currentProgress = min(targetValue, currentProgress + amount)
        if currentProgress >= targetValue {
            markComplete()
        }
    }

    /// Is quest expired?
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// Descriptive progress display (e.g., "3/5 impulses")
    var progressDisplay: String {
        let current = Int(currentProgress)
        let target = Int(targetValue)

        switch type {
        case .noSpendDays:
            return "\(current)/\(target) days"
        case .impulseResist:
            return "\(current)/\(target) impulses"
        case .savingsGoal:
            return "\(currentProgress.currencyFormatted)/\(targetValue.currencyFormatted)"
        case .challengeComplete:
            return "\(current)/\(target) challenges"
        case .streakMaintain:
            return "\(current)/\(target) days"
        case .categoryControl:
            return "\(current)/\(target) resisted"
        }
    }
}

// MARK: - Quest Type Enum
enum QuestType: String, Codable, CaseIterable, Identifiable {
    case noSpendDays = "No-Spend Days"
    case impulseResist = "Resist Impulses"
    case savingsGoal = "Savings Goal"
    case challengeComplete = "Complete Challenge"
    case streakMaintain = "Maintain Streak"
    case categoryControl = "Category Control"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .noSpendDays:
            return "checkmark.seal.fill"
        case .impulseResist:
            return "bolt.slash.fill"
        case .savingsGoal:
            return "banknote.fill"
        case .challengeComplete:
            return "trophy.fill"
        case .streakMaintain:
            return "flame.fill"
        case .categoryControl:
            return "chart.bar.fill"
        }
    }

    var description: String {
        switch self {
        case .noSpendDays:
            return "Complete days without spending"
        case .impulseResist:
            return "Resist impulse purchases"
        case .savingsGoal:
            return "Save a target amount"
        case .challengeComplete:
            return "Complete active challenges"
        case .streakMaintain:
            return "Maintain your no-spend streak"
        case .categoryControl:
            return "Control spending in a category"
        }
    }
}

// MARK: - Quest Difficulty Enum
enum QuestDifficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var baseXP: Int {
        switch self {
        case .easy: return 50
        case .medium: return 100
        case .hard: return 200
        }
    }

    var icon: String {
        switch self {
        case .easy: return "1.circle.fill"
        case .medium: return "2.circle.fill"
        case .hard: return "3.circle.fill"
        }
    }
}

// MARK: - Quest Generator
struct QuestGenerator {
    /// Generate a random daily quest
    static func generateDailyQuest() -> Quest {
        let types: [QuestType] = [.noSpendDays, .impulseResist, .savingsGoal, .categoryControl]
        let difficulties: [QuestDifficulty] = [.easy, .medium]

        let type = types.randomElement() ?? .noSpendDays
        let difficulty = difficulties.randomElement() ?? .easy

        let (title, targetValue) = generateQuestParams(type: type, difficulty: difficulty)

        return Quest(
            title: title,
            details: type.rawValue,
            type: type,
            difficulty: difficulty,
            targetValue: targetValue,
            isDaily: true
        )
    }

    /// Generate a random weekly quest
    static func generateWeeklyQuest() -> Quest {
        let types: [QuestType] = [.streakMaintain, .challengeComplete, .savingsGoal, .impulseResist]
        let difficulties: [QuestDifficulty] = [.medium, .hard]

        let type = types.randomElement() ?? .streakMaintain
        let difficulty = difficulties.randomElement() ?? .medium

        let (title, targetValue) = generateQuestParams(type: type, difficulty: difficulty)

        return Quest(
            title: title,
            details: type.rawValue,
            type: type,
            difficulty: difficulty,
            targetValue: targetValue,
            isDaily: false
        )
    }

    /// Generate quest parameters based on type and difficulty
    private static func generateQuestParams(
        type: QuestType,
        difficulty: QuestDifficulty
    ) -> (String, Double) {
        switch (type, difficulty) {
        case (.noSpendDays, .easy):
            return ("Complete 2 No-Spend Days", 2)
        case (.noSpendDays, .medium):
            return ("Complete 5 No-Spend Days", 5)
        case (.noSpendDays, .hard):
            return ("Complete 7 No-Spend Days", 7)

        case (.impulseResist, .easy):
            return ("Resist 3 Impulses", 3)
        case (.impulseResist, .medium):
            return ("Resist 5 Impulses", 5)
        case (.impulseResist, .hard):
            return ("Resist 10 Impulses", 10)

        case (.savingsGoal, .easy):
            return ("Save $25", 25)
        case (.savingsGoal, .medium):
            return ("Save $50", 50)
        case (.savingsGoal, .hard):
            return ("Save $100", 100)

        case (.challengeComplete, .easy):
            return ("Complete 1 Challenge", 1)
        case (.challengeComplete, .medium):
            return ("Complete 3 Challenges", 3)
        case (.challengeComplete, .hard):
            return ("Complete 5 Challenges", 5)

        case (.streakMaintain, .easy):
            return ("Maintain 3-Day Streak", 3)
        case (.streakMaintain, .medium):
            return ("Maintain 7-Day Streak", 7)
        case (.streakMaintain, .hard):
            return ("Maintain 14-Day Streak", 14)

        case (.categoryControl, .easy):
            return ("Resist 2 Category Impulses", 2)
        case (.categoryControl, .medium):
            return ("Resist 5 Category Impulses", 5)
        case (.categoryControl, .hard):
            return ("Resist 10 Category Impulses", 10)
        }
    }
}
