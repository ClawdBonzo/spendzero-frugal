#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only seeder for App Store screenshots. Activated by launching with the
/// `-SeedDemoData` argument (set in the Xcode scheme or via `xcrun simctl launch`).
/// Wipes existing data and inserts aspirational, realistic demo content so every
/// screen shows a thriving account instead of empty states. NEVER ships in Release.
enum DemoSeeder {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-SeedDemoData")
    }

    @MainActor
    static func seed(into context: ModelContext) {
        // Skip onboarding + paywall so screenshots land on the real app.
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        wipe(context)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // MARK: Profile (full access via active trial + premium)
        let profile = UserProfile(
            displayName: "Alex",
            dailyBudget: 40,
            monthlyIncome: 4200,
            challengeDays: 30,
            spendingLevel: .moderate,
            leakCategories: [SpendCategory.coffee.rawValue, SpendCategory.delivery.rawValue, SpendCategory.shopping.rawValue]
        )
        profile.totalSaved = 2847
        profile.currentStreak = 23
        profile.longestStreak = 41
        // Default: full access (premium) so screenshots land in the app.
        // -ShowPaywall: leave trial unstarted + not premium so RootView shows the paywall.
        let showPaywall = ProcessInfo.processInfo.arguments.contains("-ShowPaywall")
        profile.isPremium = !showPaywall
        profile.trialStartDate = showPaywall ? nil : today
        context.insert(profile)

        // MARK: Game profile — Level 12 (Diamond Defender), mid-progress
        let game = GameProfile()
        game.currentLevel = 12
        game.currentXP = 2460        // between L12 (~2229) and L13 (~2675) thresholds
        game.totalXPEarned = 13850
        game.xpMultiplier = 1.5
        context.insert(game)
        profile.gameProfile = game

        // Badges (rare/epic/legendary mix)
        let badges: [(BadgeType, BadgeRarity)] = [
            (.sevenDayStreak, .common), (.thirtyDayStreak, .rare),
            (.savedFiveHundred, .common), (.savedOneThousand, .rare),
            (.perfectWeek, .epic), (.impulseExpert, .epic),
            (.challengeChampion, .rare), (.levelTen, .legendary)
        ]
        for (i, b) in badges.enumerated() {
            let inst = BadgeInstance(badgeID: b.0, rarity: b.1)
            inst.earnedDate = cal.date(byAdding: .day, value: -i * 3, to: Date()) ?? Date()
            context.insert(inst)
            game.badges.append(inst)
            game.earnedBadgeIDs.append(b.0.rawValue)
        }

        // Active daily + weekly quests with attractive partial progress
        let quests: [(String, String, QuestType, QuestDifficulty, Double, Double, Bool)] = [
            ("No-Spend Hero", "Complete a no-spend day", .noSpendDays, .medium, 1, 1, true),
            ("Impulse Crusher", "Resist 3 impulse buys", .impulseResist, .medium, 3, 2, true),
            ("Stay Strong", "Keep your streak alive", .streakMaintain, .easy, 1, 1, true),
            ("Weekly Warrior", "Save $150 this week", .savingsGoal, .hard, 150, 110, false)
        ]
        for q in quests {
            let quest = Quest(title: q.0, details: q.1, type: q.2, difficulty: q.3, targetValue: q.4, isDaily: q.6)
            quest.currentProgress = q.5
            if q.5 >= q.4 { quest.markComplete() }
            context.insert(quest)
            game.quests.append(quest)
        }

        // MARK: 30 days of daily records — mostly no-spend (fills streak calendar green)
        // Pattern: spend days only on day offsets -27, -24, -16, -9 (rest are no-spend)
        let spendDays: Set<Int> = [27, 24, 16, 9]
        for offset in 0..<30 {
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let isSpend = spendDays.contains(offset)
            let rec = DailyRecord(date: d, isNoSpendDay: !isSpend)
            if isSpend {
                rec.totalSpent = Double([18, 32, 12, 45][offset % 4])
                rec.impulsesGivenIn = 1
                rec.mood = .tough
            } else {
                rec.totalSaved = Double([40, 35, 50, 28, 45][offset % 5])
                rec.impulsesResisted = (offset % 3 == 0) ? 2 : 1
                rec.mood = offset % 4 == 0 ? .great : .good
                rec.wins = ["Made coffee at home", "Skipped online shopping"]
            }
            context.insert(rec)
        }

        // MARK: Impulse logs — mostly resisted, realistic items (impulse logger screen)
        let impulses: [(String, Double, SpendCategory, Bool)] = [
            ("Nike Air Max sneakers", 130, .clothing, true),
            ("Espresso machine", 249, .electronics, true),
            ("DoorDash dinner", 32, .delivery, true),
            ("Impulse Amazon cart", 78, .shopping, true),
            ("New phone case", 24, .electronics, true),
            ("Concert resale ticket", 165, .entertainment, true),
            ("Designer sunglasses", 95, .clothing, true),
            ("Late-night snacks", 18, .snacks, false)
        ]
        for (i, imp) in impulses.enumerated() {
            let log = ImpulseLog(
                item: imp.0, estimatedCost: imp.1, category: imp.2, wasResisted: imp.3,
                triggerNote: "Saw an ad", copingStrategy: "Waited 24 hours"
            )
            log.date = cal.date(byAdding: .hour, value: -i * 7, to: Date()) ?? Date()
            context.insert(log)
        }

        // MARK: Savings entries (feed totals/charts) ~ matches totalSaved
        let savings: [(Double, SavingsSource, Int)] = [
            (130, .impulseResisted, 0), (249, .impulseResisted, 1), (40, .noSpendDay, 2),
            (165, .impulseResisted, 3), (95, .impulseResisted, 4), (60, .mealPrepped, 5),
            (200, .challengeBonus, 7), (45, .noSpendDay, 8), (78, .impulseResisted, 10),
            (120, .subscriptionCanceled, 12), (40, .noSpendDay, 14), (35, .noSpendDay, 16)
        ]
        for s in savings {
            let entry = SavingsEntry(amount: s.0, date: cal.date(byAdding: .day, value: -s.2, to: Date()) ?? Date(), source: s.1)
            context.insert(entry)
        }

        // A few spending logs for chart balance
        for (i, amt) in [18.0, 32, 12, 45].enumerated() {
            let sp = SpendingLog(amount: amt, category: [.coffee, .delivery, .snacks, .shopping][i],
                                 date: cal.date(byAdding: .day, value: -[27, 24, 16, 9][i], to: today) ?? today,
                                 wasImpulse: true)
            context.insert(sp)
        }

        // Active challenge
        let challenge = ChallengeEntry(
            title: "30-Day No-Spend Challenge",
            challengeDescription: "Cut all non-essential spending for 30 days.",
            durationDays: 30, category: .noSpend, difficulty: .medium, estimatedSavings: 600
        )
        challenge.isActive = true
        challenge.startDate = cal.date(byAdding: .day, value: -23, to: today)
        challenge.completedDays = 23
        context.insert(challenge)

        try? context.save()
        WidgetSync.refresh(profile: profile, context: context)
    }

    @MainActor
    private static func wipe(_ context: ModelContext) {
        try? context.delete(model: SpendingLog.self)
        try? context.delete(model: SavingsEntry.self)
        try? context.delete(model: DailyRecord.self)
        try? context.delete(model: ImpulseLog.self)
        try? context.delete(model: ChallengeEntry.self)
        try? context.delete(model: Quest.self)
        try? context.delete(model: BadgeInstance.self)
        try? context.delete(model: GameProfile.self)
        try? context.delete(model: UserProfile.self)
        try? context.save()
    }
}
#endif
