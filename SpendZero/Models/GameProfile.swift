import Foundation
import SwiftData

/// Main gamification profile tied to each UserProfile (one-to-one relationship)
@Model
final class GameProfile {
    /// Unique identifier
    var id: UUID

    // MARK: - Level & XP Tracking
    /// Current level (1-25)
    var currentLevel: Int = 1
    /// XP earned toward current level
    var currentXP: Int = 0
    /// Total cumulative XP earned (all-time)
    var totalXPEarned: Int = 0

    // MARK: - Badges & Rewards
    /// Earned badges (max 20 displayed)
    var badges: [BadgeInstance] = []
    /// Badge IDs that user has earned (for fast lookup)
    var earnedBadgeIDs: [String] = []

    // MARK: - Quests
    /// Current active quests (daily + weekly)
    @Relationship(deleteRule: .cascade) var quests: [Quest] = []
    /// Quest IDs user has completed (for history)
    var completedQuestIDs: [String] = []

    // MARK: - Multipliers & State
    /// XP multiplier based on current streak (1.0x to 1.5x)
    var xpMultiplier: Double = 1.0
    /// Last date XP was updated (for daily login bonus)
    var lastXPUpdateDate: Date = Date()
    /// Last date quests were reset (for daily/weekly cycling)
    var lastQuestResetDate: Date = Date()

    // MARK: - Premium Features
    /// Whether user has unlocked cosmetic badges (paid feature)
    var hasPremiumCosmetics: Bool = false
    /// Favorite cosmetic badge ID (if purchased)
    var favoriteCosmetic: String?

    init() {
        self.id = UUID()
    }

    /// Calculate XP needed for current level
    var xpThresholdForCurrentLevel: Int {
        let baseThreshold = 300
        let growthRate = 1.2
        let level = Double(currentLevel - 1)
        return Int(Double(baseThreshold) * pow(growthRate, level))
    }

    /// Calculate XP needed for next level
    var xpThresholdForNextLevel: Int {
        let baseThreshold = 300
        let growthRate = 1.2
        let level = Double(currentLevel)
        return Int(Double(baseThreshold) * pow(growthRate, level))
    }

    /// Progress toward next level (0.0 to 1.0)
    var progressToNextLevel: Double {
        let threshold = xpThresholdForCurrentLevel
        let nextThreshold = xpThresholdForNextLevel
        let progress = nextThreshold - threshold
        let earned = currentXP - threshold
        return max(0, min(1, Double(earned) / Double(progress)))
    }

    /// Get the current level rank (name)
    var currentRank: LevelRank {
        LevelRank(rawValue: currentLevel) ?? .wealthKing
    }

    /// Earned badges limited to 20 most recent
    var displayedBadges: [BadgeInstance] {
        Array(badges.sorted(by: { $0.earnedDate > $1.earnedDate }).prefix(20))
    }
}

// MARK: - Level Rank Enum
enum LevelRank: Int, Codable, CaseIterable {
    case frugalNovice = 1
    case pennyPincher = 2
    case budgetWarden = 3
    case moneyMindful = 4
    case financialGuardian = 5
    case savingsSentinel = 6
    case wealthBuilder = 7
    case fortuneWeaver = 8
    case goldGatherer = 9
    case treasureHunter = 10
    case platinumMaster = 11
    case diamondDefender = 12
    case wealthKing = 25  // Final legendary tier

    // Fill levels 13-24 generically
    case level13 = 13, level14 = 14, level15 = 15
    case level16 = 16, level17 = 17, level18 = 18
    case level19 = 19, level20 = 20, level21 = 21
    case level22 = 22, level23 = 23, level24 = 24

    var title: String {
        switch self {
        case .frugalNovice: return String(localized: "Frugal Novice")
        case .pennyPincher: return String(localized: "Penny Pincher")
        case .budgetWarden: return String(localized: "Budget Warden")
        case .moneyMindful: return String(localized: "Money Mindful")
        case .financialGuardian: return String(localized: "Financial Guardian")
        case .savingsSentinel: return String(localized: "Savings Sentinel")
        case .wealthBuilder: return String(localized: "Wealth Builder")
        case .fortuneWeaver: return String(localized: "Fortune Weaver")
        case .goldGatherer: return String(localized: "Gold Gatherer")
        case .treasureHunter: return String(localized: "Treasure Hunter")
        case .platinumMaster: return String(localized: "Platinum Master")
        case .diamondDefender: return String(localized: "Diamond Defender")
        case .wealthKing: return String(localized: "Wealth King")
        case .level13: return String(localized: "Ascendant")
        case .level14: return String(localized: "Luminary")
        case .level15: return String(localized: "Radiant")
        case .level16: return String(localized: "Apex")
        case .level17: return String(localized: "Summit")
        case .level18: return String(localized: "Monument")
        case .level19: return String(localized: "Titan")
        case .level20: return String(localized: "Aegis")
        case .level21: return String(localized: "Sovereign")
        case .level22: return String(localized: "Paramount")
        case .level23: return String(localized: "Supreme")
        case .level24: return String(localized: "Imperial")
        }
    }

    /// Unlock features per tier
    var unlockedFeatures: [String] {
        switch self {
        case .frugalNovice, .pennyPincher:
            return ["Daily Quests"]
        case .budgetWarden, .moneyMindful:
            return ["Daily Quests", "Weekly Quests", "Advanced Badges"]
        case .financialGuardian, .savingsSentinel:
            return ["Daily Quests", "Weekly Quests", "Premium Flames", "Achievements"]
        case .wealthBuilder, .fortuneWeaver:
            return ["Daily Quests", "Weekly Quests", "Money Tree Visualization", "Challenge Bonuses"]
        case .goldGatherer, .treasureHunter:
            return ["All Quest Types", "Special Badges", "Statistics", "Milestones"]
        case .platinumMaster, .diamondDefender:
            return ["All Features", "Exclusive Cosmetics", "Statistics Pro"]
        case .wealthKing:
            return ["All Features Unlocked", "Legendary Status", "Hall of Fame"]
        default:
            return ["Advanced Features"]
        }
    }
}

// MARK: - XP Action Types
enum XPAction: String, Codable {
    case noSpendDay = "no-spend-day"
    case impulseResisted = "impulse-resisted"
    case challengeCompleted = "challenge-completed"
    case questCompleted = "quest-completed"
    case loginStreak = "login-streak"
    case impulseSpree = "impulse-spree"      // 5+ impulses resisted in one day
    case weeklyChallenge = "weekly-challenge"

    var baseXP: Int {
        switch self {
        case .noSpendDay: return 100
        case .impulseResisted: return 25
        case .challengeCompleted: return 30
        case .questCompleted: return 75      // Varies by difficulty
        case .loginStreak: return 10
        case .impulseSpree: return 50
        case .weeklyChallenge: return 100
        }
    }
}
