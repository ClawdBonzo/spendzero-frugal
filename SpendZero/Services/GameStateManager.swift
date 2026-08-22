import Foundation
import SwiftData

/// Pure gamification rules: XP grants, level-ups, badge unlocks, quest generation/rollover.
/// Only `ProgressEngine` should call these; views read state, they never mutate it.
@MainActor
final class GameStateManager {
    static let shared = GameStateManager()
    private init() {}

    struct XPResult {
        var xpGranted: Int
        var leveledUp: Bool
        var previousLevel: Int
        var newLevel: Int
        var badgesUnlocked: [BadgeInstance]
        var luckyBonus: Bool
    }

    // MARK: - XP & Levels

    /// Grant XP for an action. Streak multiplier applies to day/impulse actions; an occasional
    /// "lucky" double keeps the loop from being fully predictable.
    @discardableResult
    func grantXP(action: XPAction, to gp: GameProfile, multiplier: Double = 1.0) -> XPResult {
        var xp = action.baseXP
        if action == .noSpendDay || action == .impulseResisted || action == .challengeCompleted {
            xp = Int(Double(xp) * multiplier)
        }
        var lucky = false
        if action == .noSpendDay || action == .impulseResisted, Int.random(in: 1...10) == 1 {
            xp *= 2
            lucky = true
        }
        var r = grantXP(amount: xp, to: gp)
        r.luckyBonus = lucky
        return r
    }

    /// Grant a raw XP amount (used for quest rewards, which already scale by difficulty).
    @discardableResult
    func grantXP(amount: Int, to gp: GameProfile) -> XPResult {
        let previous = gp.currentLevel
        var badges: [BadgeInstance] = []
        gp.totalXPEarned += amount
        gp.lastXPUpdateDate = Date()

        if gp.isMaxLevel {
            return XPResult(xpGranted: amount, leveledUp: false, previousLevel: previous,
                            newLevel: previous, badgesUnlocked: [], luckyBonus: false)
        }

        gp.currentXP += amount
        while !gp.isMaxLevel, gp.currentXP >= gp.xpThresholdForNextLevel {
            gp.currentXP -= gp.xpThresholdForNextLevel
            gp.currentLevel += 1
            if gp.currentLevel == 10, let b = unlock(.levelTen, rarity: .epic, in: gp) { badges.append(b) }
            if gp.currentLevel == GameProfile.maxLevel {
                if let b = unlock(.levelTwentyFive, rarity: .legendary, in: gp) { badges.append(b) }
                gp.currentXP = 0
            }
        }
        return XPResult(xpGranted: amount, leveledUp: gp.currentLevel > previous, previousLevel: previous,
                        newLevel: gp.currentLevel, badgesUnlocked: badges, luckyBonus: false)
    }

    func calculateStreakMultiplier(streak: Int) -> Double {
        switch streak {
        case ..<8: return 1.0
        case 8...14: return 1.1
        case 15...30: return 1.2
        default: return 1.5
        }
    }

    // MARK: - Badges

    /// Unlock a badge once. Returns the new instance, or nil if already earned.
    @discardableResult
    func unlock(_ type: BadgeType, rarity: BadgeRarity, in gp: GameProfile) -> BadgeInstance? {
        guard !gp.earnedBadgeIDs.contains(type.rawValue),
              !gp.badges.contains(where: { $0.badgeID == type }) else { return nil }
        gp.earnedBadgeIDs.append(type.rawValue)
        let badge = BadgeInstance(badgeID: type, rarity: rarity)
        gp.badges.append(badge)
        return badge
    }

    func checkStreakBadges(for gp: GameProfile, currentStreak: Int) -> [BadgeInstance] {
        let thresholds: [(Int, BadgeType, BadgeRarity)] = [
            (7, .sevenDayStreak, .rare), (30, .thirtyDayStreak, .epic),
            (100, .hundredDayStreak, .epic), (365, .oneYearStreak, .legendary),
        ]
        return thresholds.compactMap { days, type, rarity in
            currentStreak >= days ? unlock(type, rarity: rarity, in: gp) : nil
        }
    }

    func checkSavingsBadges(for gp: GameProfile, totalSaved: Double) -> [BadgeInstance] {
        let thresholds: [(Double, BadgeType, BadgeRarity)] = [
            (500, .savedFiveHundred, .common), (1000, .savedOneThousand, .rare),
            (5000, .savedFiveThousand, .epic), (10000, .savedTenThousand, .legendary),
        ]
        return thresholds.compactMap { amount, type, rarity in
            totalSaved >= amount ? unlock(type, rarity: rarity, in: gp) : nil
        }
    }

    func checkAchievementBadges(for gp: GameProfile, impulseCount: Int, completedChallenges: Int,
                                consecutiveNoSpendDays: Int) -> [BadgeInstance] {
        var out: [BadgeInstance] = []
        if consecutiveNoSpendDays >= 7, let b = unlock(.perfectWeek, rarity: .rare, in: gp) { out.append(b) }
        if impulseCount >= 50, let b = unlock(.impulseExpert, rarity: .rare, in: gp) { out.append(b) }
        if impulseCount >= 10, let b = unlock(.momentum, rarity: .common, in: gp) { out.append(b) }
        if completedChallenges >= 1, let b = unlock(.speedSaver, rarity: .common, in: gp) { out.append(b) }
        if completedChallenges >= 5, let b = unlock(.challengeChampion, rarity: .rare, in: gp) { out.append(b) }
        return out
    }

    // MARK: - Quests

    func generateDailyQuests() -> [Quest] {
        let count = Int.random(in: 1...2)
        var types: [QuestType] = [.noSpendDays, .impulseResist, .savingsGoal, .categoryControl].shuffled()
        return (0..<count).compactMap { _ in
            guard let type = types.popLast() else { return nil }
            return QuestGenerator.make(type: type, difficulty: [.easy, .medium].randomElement()!, isDaily: true)
        }
    }

    func generateWeeklyQuest() -> Quest {
        let type: QuestType = [.streakMaintain, .noSpendDays, .savingsGoal, .impulseResist, .challengeComplete].randomElement()!
        return QuestGenerator.make(type: type, difficulty: [.medium, .hard].randomElement()!, isDaily: false)
    }

    /// Roll quests over on day/week boundaries. Expired quests are deleted (not just detached).
    func refreshQuestsIfNeeded(for gp: GameProfile, context: ModelContext, now: Date = Date()) {
        let cal = Calendar.current
        let lastDay = cal.startOfDay(for: gp.lastQuestResetDate)
        let today = cal.startOfDay(for: now)
        let newDay = today > lastDay
        let newWeek = !cal.isDate(gp.lastQuestResetDate, equalTo: now, toGranularity: .weekOfYear)

        let expired = gp.quests.filter { $0.isExpired(asOf: now) }
        guard newDay || newWeek || !expired.isEmpty else { return }

        for quest in expired {
            gp.quests.removeAll { $0 === quest }
            context.delete(quest)
        }
        if !gp.quests.contains(where: { $0.isDaily }) {
            gp.quests.append(contentsOf: generateDailyQuests())
        }
        if !gp.quests.contains(where: { !$0.isDaily }) {
            gp.quests.append(generateWeeklyQuest())
        }
        gp.lastQuestResetDate = now
    }
}
