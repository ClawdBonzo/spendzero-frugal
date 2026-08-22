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

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if isDaily {
            self.expiresAt = cal.date(byAdding: .day, value: 1, to: today) ?? Date()
        } else {
            self.expiresAt = cal.date(byAdding: .day, value: 7, to: today) ?? Date()
        }
    }

    /// Localized title built from type + target so it's never stuck in the language it was created in.
    var displayTitle: String {
        let n = Int(targetValue)
        switch type {
        case .noSpendDays:
            return isDaily ? String(localized: "Log today as a no-spend day")
                           : String(localized: "Complete \(n) no-spend days this week")
        case .impulseResist:
            return n == 1 ? String(localized: "Resist 1 impulse") : String(localized: "Resist \(n) impulses")
        case .savingsGoal:
            return String(localized: "Save \(targetValue.currencyFormatted)")
        case .challengeComplete:
            return n == 1 ? String(localized: "Complete 1 challenge") : String(localized: "Complete \(n) challenges")
        case .streakMaintain:
            return String(localized: "Reach a \(n)-day streak")
        case .categoryControl:
            return n == 1 ? String(localized: "Resist 1 impulse in a leak category")
                          : String(localized: "Resist \(n) impulses in your leak categories")
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
    var isExpired: Bool { isExpired(asOf: Date()) }
    func isExpired(asOf now: Date) -> Bool { now >= expiresAt }

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
    /// Targets are sized so daily quests are achievable within one day and weekly ones within a week.
    static func make(type: QuestType, difficulty: QuestDifficulty, isDaily: Bool) -> Quest {
        let target: Double
        switch (type, isDaily, difficulty) {
        case (.noSpendDays, true, _):            target = 1
        case (.noSpendDays, false, .easy):       target = 3
        case (.noSpendDays, false, .medium):     target = 4
        case (.noSpendDays, false, .hard):       target = 6
        case (.impulseResist, true, .easy):      target = 1
        case (.impulseResist, true, _):          target = 2
        case (.impulseResist, false, .easy):     target = 3
        case (.impulseResist, false, .medium):   target = 5
        case (.impulseResist, false, .hard):     target = 10
        case (.savingsGoal, true, .easy):        target = 10
        case (.savingsGoal, true, _):            target = 25
        case (.savingsGoal, false, .easy):       target = 50
        case (.savingsGoal, false, .medium):     target = 100
        case (.savingsGoal, false, .hard):       target = 250
        case (.challengeComplete, _, _):         target = 1
        case (.streakMaintain, _, .easy):        target = 3
        case (.streakMaintain, _, .medium):      target = 7
        case (.streakMaintain, _, .hard):        target = 14
        case (.categoryControl, true, _):        target = 1
        case (.categoryControl, false, .easy):   target = 2
        case (.categoryControl, false, .medium): target = 3
        case (.categoryControl, false, .hard):   target = 5
        }
        let quest = Quest(title: "", details: type.rawValue, type: type, difficulty: difficulty,
                          targetValue: target, isDaily: isDaily)
        quest.title = quest.displayTitle
        return quest
    }
}
