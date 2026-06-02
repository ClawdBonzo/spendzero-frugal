import Foundation
import SwiftData

/// Singleton service managing gamification state: XP grants, level-ups, badge unlocks, quest generation
final class GameStateManager: @unchecked Sendable {
    static let shared = GameStateManager()

    private init() {}

    // MARK: - XP & Level Management

    /// Grant XP for an action, potentially triggering level-up and badge unlocks
    /// - Returns: (xpGranted, leveledUp, newLevel, badgesUnlocked)
    func grantXP(
        action: XPAction,
        to gameProfile: GameProfile,
        streak: Int,
        multiplier: Double = 1.0,
        context: ModelContext? = nil
    ) -> (xpGranted: Int, leveledUp: Bool, newLevel: Int, badgesUnlocked: [BadgeType], luckyBonus: Bool) {
        var baseXP = action.baseXP
        var badgesUnlocked: [BadgeType] = []

        // Apply streak multiplier (except for quests which already scale)
        if action != .questCompleted {
            baseXP = Int(Double(baseXP) * multiplier)
        }

        // Variable reward: an occasional surprise "lucky" double-XP keeps the core
        // loop from becoming fully predictable (predictable rewards habituate fast).
        var luckyBonus = false
        if action == .noSpendDay || action == .impulseResisted, Int.random(in: 1...10) == 1 {
            baseXP *= 2
            luckyBonus = true
        }

        let oldLevel = gameProfile.currentLevel
        gameProfile.totalXPEarned += baseXP
        gameProfile.currentXP += baseXP

        // Check for level-up(s)
        var leveledUp = false
        var leveledUpCount = 0
        while gameProfile.currentXP >= gameProfile.xpThresholdForNextLevel {
            gameProfile.currentXP -= gameProfile.xpThresholdForNextLevel
            gameProfile.currentLevel += 1
            leveledUp = true
            leveledUpCount += 1

            // Unlock level badge
            if gameProfile.currentLevel == 10 {
                badgesUnlocked.append(.levelTen)
                if !gameProfile.earnedBadgeIDs.contains(BadgeType.levelTen.rawValue) {
                    gameProfile.earnedBadgeIDs.append(BadgeType.levelTen.rawValue)
                    let badge = BadgeInstance(badgeID: .levelTen, rarity: .epic)
                    gameProfile.badges.append(badge)
                }
            } else if gameProfile.currentLevel == 25 {
                badgesUnlocked.append(.levelTwentyFive)
                if !gameProfile.earnedBadgeIDs.contains(BadgeType.levelTwentyFive.rawValue) {
                    gameProfile.earnedBadgeIDs.append(BadgeType.levelTwentyFive.rawValue)
                    let badge = BadgeInstance(badgeID: .levelTwentyFive, rarity: .legendary)
                    gameProfile.badges.append(badge)
                }
            }
        }

        gameProfile.lastXPUpdateDate = Date()

        return (xpGranted: baseXP, leveledUp: leveledUp, newLevel: gameProfile.currentLevel, badgesUnlocked: badgesUnlocked, luckyBonus: luckyBonus)
    }

    /// Calculate XP multiplier based on current streak
    func calculateStreakMultiplier(streak: Int) -> Double {
        switch streak {
        case 1...7:
            return 1.0
        case 8...14:
            return 1.1
        case 15...30:
            return 1.2
        default:
            return 1.5  // Capped at 1.5x
        }
    }

    // MARK: - Badge Unlock Management

    /// Check and unlock streak-based badges
    func checkStreakBadges(
        for gameProfile: GameProfile,
        currentStreak: Int
    ) -> [BadgeType] {
        var newBadges: [BadgeType] = []

        let streakBadges: [(Int, BadgeType)] = [
            (7, .sevenDayStreak),
            (30, .thirtyDayStreak),
            (100, .hundredDayStreak),
            (365, .oneYearStreak),
        ]

        for (streakThreshold, badgeType) in streakBadges {
            if currentStreak >= streakThreshold, !gameProfile.earnedBadgeIDs.contains(badgeType.rawValue) {
                gameProfile.earnedBadgeIDs.append(badgeType.rawValue)
                let badge = BadgeInstance(badgeID: badgeType, rarity: rarityForStreak(streakThreshold))
                gameProfile.badges.append(badge)
                newBadges.append(badgeType)
            }
        }

        return newBadges
    }

    /// Check and unlock savings-based badges
    func checkSavingsBadges(
        for gameProfile: GameProfile,
        totalSaved: Double
    ) -> [BadgeType] {
        var newBadges: [BadgeType] = []

        let savingsBadges: [(Double, BadgeType)] = [
            (500, .savedFiveHundred),
            (1000, .savedOneThousand),
            (5000, .savedFiveThousand),
            (10000, .savedTenThousand),
        ]

        for (saveThreshold, badgeType) in savingsBadges {
            if totalSaved >= saveThreshold, !gameProfile.earnedBadgeIDs.contains(badgeType.rawValue) {
                gameProfile.earnedBadgeIDs.append(badgeType.rawValue)
                let badge = BadgeInstance(badgeID: badgeType, rarity: rarityForSavings(saveThreshold))
                gameProfile.badges.append(badge)
                newBadges.append(badgeType)
            }
        }

        return newBadges
    }

    /// Check for achievement-based badges
    func checkAchievementBadges(
        for gameProfile: GameProfile,
        impulseCount: Int,
        completedChallenges: Int,
        consecutiveNoSpendDays: Int
    ) -> [BadgeType] {
        var newBadges: [BadgeType] = []

        // Perfect Week: 7 consecutive no-spend days
        if consecutiveNoSpendDays >= 7, !gameProfile.earnedBadgeIDs.contains(BadgeType.perfectWeek.rawValue) {
            gameProfile.earnedBadgeIDs.append(BadgeType.perfectWeek.rawValue)
            let badge = BadgeInstance(badgeID: .perfectWeek, rarity: .rare)
            gameProfile.badges.append(badge)
            newBadges.append(.perfectWeek)
        }

        // Impulse Expert: 50+ impulses resisted
        if impulseCount >= 50, !gameProfile.earnedBadgeIDs.contains(BadgeType.impulseExpert.rawValue) {
            gameProfile.earnedBadgeIDs.append(BadgeType.impulseExpert.rawValue)
            let badge = BadgeInstance(badgeID: .impulseExpert, rarity: .rare)
            gameProfile.badges.append(badge)
            newBadges.append(.impulseExpert)
        }

        // Challenge Champion: 5 challenges completed
        if completedChallenges >= 5, !gameProfile.earnedBadgeIDs.contains(BadgeType.challengeChampion.rawValue) {
            gameProfile.earnedBadgeIDs.append(BadgeType.challengeChampion.rawValue)
            let badge = BadgeInstance(badgeID: .challengeChampion, rarity: .rare)
            gameProfile.badges.append(badge)
            newBadges.append(.challengeChampion)
        }

        return newBadges
    }

    // MARK: - Quest Management

    /// Generate daily quests for the game profile
    func generateDailyQuests(for gameProfile: GameProfile) -> [Quest] {
        // Generate 1-2 daily quests
        let questCount = Int.random(in: 1...2)
        let quests = (0..<questCount).map { _ in QuestGenerator.generateDailyQuest() }
        return quests
    }

    /// Generate weekly quest for the game profile
    func generateWeeklyQuest(for gameProfile: GameProfile) -> Quest {
        QuestGenerator.generateWeeklyQuest()
    }

    /// Check if quests need to be reset and regenerate
    func refreshQuestsIfNeeded(for gameProfile: GameProfile) {
        let calendar = Calendar.current
        let daysSinceReset = calendar.dateComponents([.day], from: gameProfile.lastQuestResetDate, to: Date()).day ?? 0

        var shouldResetDaily = false
        var shouldResetWeekly = false

        // Daily quests reset every 24 hours
        if daysSinceReset >= 1 {
            shouldResetDaily = true
        }

        // Weekly quests reset when the calendar week changes — NOT only if the user
        // happens to open the app on a Monday (which could leave them quest-less for
        // up to a week).
        let lastWeek = calendar.component(.weekOfYear, from: gameProfile.lastQuestResetDate)
        let thisWeek = calendar.component(.weekOfYear, from: Date())
        let lastWeekYear = calendar.component(.yearForWeekOfYear, from: gameProfile.lastQuestResetDate)
        let thisWeekYear = calendar.component(.yearForWeekOfYear, from: Date())
        if thisWeek != lastWeek || thisWeekYear != lastWeekYear {
            shouldResetWeekly = true
        }

        if shouldResetDaily || shouldResetWeekly {
            // Remove expired quests
            gameProfile.quests.removeAll { $0.isExpired }

            if shouldResetDaily {
                // Generate new daily quests
                let dailyQuests = generateDailyQuests(for: gameProfile)
                gameProfile.quests.append(contentsOf: dailyQuests)
            }

            if shouldResetWeekly {
                // Generate a new weekly quest only if there isn't an active one already
                // (avoids stacking duplicates when a week rolls over mid-quest).
                if !gameProfile.quests.contains(where: { !$0.isDaily && !$0.isExpired }) {
                    let weeklyQuest = generateWeeklyQuest(for: gameProfile)
                    gameProfile.quests.append(weeklyQuest)
                }
            }

            gameProfile.lastQuestResetDate = Date()
        }
    }

    // MARK: - Helper Methods

    private func rarityForStreak(_ days: Int) -> BadgeRarity {
        switch days {
        case 7: return .rare
        case 30: return .epic
        case 100: return .epic
        case 365: return .legendary
        default: return .common
        }
    }

    private func rarityForSavings(_ amount: Double) -> BadgeRarity {
        switch amount {
        case 500: return .common
        case 1000: return .rare
        case 5000: return .epic
        case 10000: return .legendary
        default: return .common
        }
    }
}

// MARK: - Extension: Quick Helpers

extension GameProfile {
    /// Quick method to grant XP via shared manager
    func grantXP(
        _ action: XPAction,
        streak: Int,
        multiplier: Double = 1.0
    ) -> (xpGranted: Int, leveledUp: Bool, newLevel: Int, badgesUnlocked: [BadgeType], luckyBonus: Bool) {
        GameStateManager.shared.grantXP(action: action, to: self, streak: streak, multiplier: multiplier)
    }
}
