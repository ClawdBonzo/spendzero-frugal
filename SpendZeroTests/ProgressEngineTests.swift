import Testing
import Foundation
import SwiftData
@testable import SpendZero

@MainActor
struct ProgressEngineTests {
    /// Keeps the container alive for the duration of a test (the context only holds it weakly).
    final class Store {
        let container: ModelContainer
        let context: ModelContext
        let profile: UserProfile
        init(container: ModelContainer, context: ModelContext, profile: UserProfile) {
            self.container = container; self.context = context; self.profile = profile
        }
    }

    private func makeStore() throws -> Store {
        let schema = Schema(versionedSchema: SpendZeroSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let profile = UserProfile(displayName: "T", dailyBudget: 20)
        context.insert(profile)
        ProgressEngine.shared.reconcileOnActivate(profile: profile, context: context)
        return Store(container: container, context: context, profile: profile)
    }

    @Test func markingNoSpendDayAdvancesStreakSavingsAndQuests() throws {
        let store = try makeStore(); let ctx = store.context; let profile = store.profile
        let gp = try #require(profile.gameProfile)
        // Force a known daily quest so the assertion is deterministic.
        gp.quests.removeAll()
        gp.quests.append(QuestGenerator.make(type: .noSpendDays, difficulty: .easy, isDaily: true))

        let outcome = try #require(ProgressEngine.shared.logNoSpendDay(profile: profile, context: ctx))
        #expect(profile.currentStreak == 1)
        #expect(profile.totalSaved == 20)
        #expect(outcome.xpGranted >= XPAction.noSpendDay.baseXP)
        #expect(outcome.questsCompleted.count == 1)
        #expect(gp.completedQuestIDs.count == 1)
        // Second mark the same day is a no-op.
        #expect(ProgressEngine.shared.logNoSpendDay(profile: profile, context: ctx) == nil)
        #expect(profile.currentStreak == 1)
    }

    @Test func nonEssentialSpendingBlocksAndRevertsNoSpendDay() throws {
        let store = try makeStore(); let ctx = store.context; let profile = store.profile
        _ = ProgressEngine.shared.logNoSpendDay(profile: profile, context: ctx)
        #expect(profile.currentStreak == 1)

        let reverted = ProgressEngine.shared.logSpending(amount: 12, category: .coffee, note: "", wasImpulse: false,
                                                         profile: profile, context: ctx)
        #expect(reverted)
        #expect(profile.currentStreak == 0)
        #expect(profile.totalSaved == 0)
        #expect(ProgressEngine.shared.noSpendDayBlocker(profile: profile, context: ctx) == .spentToday)
        #expect(ProgressEngine.shared.logNoSpendDay(profile: profile, context: ctx) == nil)
    }

    @Test func essentialSpendingDoesNotBreakTheDay() throws {
        let store = try makeStore(); let ctx = store.context; let profile = store.profile
        ProgressEngine.shared.logSpending(amount: 60, category: .groceries, note: "", wasImpulse: false,
                                          profile: profile, context: ctx)
        #expect(ProgressEngine.shared.noSpendDayBlocker(profile: profile, context: ctx) == nil)
        #expect(ProgressEngine.shared.logNoSpendDay(profile: profile, context: ctx) != nil)
    }

    @Test func winsCannotFarmXPAndUncheckRemovesSavingsEntry() throws {
        let store = try makeStore(); let ctx = store.context; let profile = store.profile
        let gp = try #require(profile.gameProfile)
        gp.quests.removeAll()   // random quests could pay out and confuse the XP assertion
        let win = WinItem.all[0]
        let xpBefore = gp.totalXPEarned

        _ = ProgressEngine.shared.toggleWin(win, profile: profile, context: ctx)   // check
        let afterFirst = gp.totalXPEarned
        #expect(afterFirst == xpBefore + XPAction.dailyWin.baseXP)
        _ = ProgressEngine.shared.toggleWin(win, profile: profile, context: ctx)   // uncheck
        _ = ProgressEngine.shared.toggleWin(win, profile: profile, context: ctx)   // check again
        #expect(gp.totalXPEarned == afterFirst)
        #expect(profile.totalSaved == win.savedAmount)
        let entries = try ctx.fetch(FetchDescriptor<SavingsEntry>())
        #expect(entries.count == 1)
    }

    @Test func challengeAdvancesOncePerDayAndCompletes() throws {
        let store = try makeStore(); let ctx = store.context; let profile = store.profile
        let challenge = ChallengeEntry(title: "1-Day", challengeDescription: "", durationDays: 1,
                                       category: .noSpend, difficulty: .easy, estimatedSavings: 10)
        ctx.insert(challenge)
        ProgressEngine.shared.startChallenge(challenge, all: [challenge], profile: profile, context: ctx)
        let outcome = try #require(ProgressEngine.shared.logNoSpendDay(profile: profile, context: ctx))
        #expect(challenge.completedDays == 1)
        #expect(challenge.isCompleted)
        #expect(outcome.challengeCompleted === challenge)
    }

    @Test func resistedImpulseEarnsXPAndQuestProgress() throws {
        let store = try makeStore(); let ctx = store.context; let profile = store.profile
        let gp = try #require(profile.gameProfile)
        gp.quests.removeAll()
        gp.quests.append(QuestGenerator.make(type: .impulseResist, difficulty: .easy, isDaily: true))
        let outcome = try #require(ProgressEngine.shared.logImpulse(item: "Shoes", cost: 80, category: .shopping,
                                                                     resisted: true, triggerNote: "", copingStrategy: "",
                                                                     profile: profile, context: ctx))
        #expect(outcome.xpGranted > 0)
        #expect(outcome.questsCompleted.count == 1)
        #expect(profile.totalSaved == 80)
        // Giving in earns nothing.
        #expect(ProgressEngine.shared.logImpulse(item: "Bag", cost: 30, category: .shopping, resisted: false,
                                                 triggerNote: "", copingStrategy: "", profile: profile, context: ctx) == nil)
    }
}
