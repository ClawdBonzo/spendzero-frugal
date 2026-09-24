import Foundation
import SwiftData

/// The single place where user actions turn into progress.
///
/// Every flow that changes the user's state (marking a no-spend day, logging spending or an
/// impulse, checking a win, resetting) goes through here so that streak, quests, challenges,
/// badges, XP, the widget and notifications always move together. Views never touch
/// gamification state directly.
@MainActor
final class ProgressEngine {
    static let shared = ProgressEngine()
    private init() {}

    // MARK: - Outcome

    /// What happened as a result of one action, for the UI to celebrate.
    struct Outcome {
        var xpGranted = 0
        var luckyBonus = false
        var levelUp: (previous: Int, new: Int)?
        var badgesUnlocked: [BadgeInstance] = []
        var questsCompleted: [Quest] = []
        var challengeCompleted: ChallengeEntry?
        var newStreak: Int?
        var streakFreezeEarned = false
        var streakOutcome: UserProfile.StreakOutcome = .intact
        /// Savings credited by this action (the day's budget for a no-spend day).
        var savedAmount: Double = 0
        /// Lifetime count of no-spend days, including this one.
        var totalNoSpendDays: Int = 0
        /// Set when this action crossed a moment worth asking for an App Store rating.
        var reviewMilestone: String?

        var isEmpty: Bool {
            xpGranted == 0 && levelUp == nil && badgesUnlocked.isEmpty
                && questsCompleted.isEmpty && challengeCompleted == nil
        }
    }

    static let maxStreakFreezes = 3

    // MARK: - Lifecycle

    /// Call when the app launches or returns to the foreground. Reconciles the streak against
    /// the calendar, rolls quests over, applies any mark made from the widget, and re-arms
    /// the widget + notifications. Returns the streak outcome so the UI can surface it.
    @discardableResult
    func reconcileOnActivate(profile: UserProfile?, context: ModelContext, now: Date = Date()) -> Outcome {
        var outcome = Outcome()
        guard let profile else { return outcome }

        let gp = ensureGameProfile(for: profile, context: context)
        GameStateManager.shared.refreshQuestsIfNeeded(for: gp, context: context, now: now)

        backfillLastNoSpendDateIfNeeded(profile: profile, context: context)
        outcome.streakOutcome = profile.reconcileStreak(asOf: now)

        // A no-spend day marked from the Home Screen widget while the app was closed.
        if let pending = consumePendingWidgetMark(), Calendar.current.isDate(pending, inSameDayAs: now) {
            if let marked = logNoSpendDay(profile: profile, context: context, now: now) {
                outcome = marked
            }
        }

        save(context)
        syncWidget(profile: profile, context: context, now: now)
        refreshNotifications(profile: profile, now: now)
        return outcome
    }

    // MARK: - Actions

    /// Whether today can be marked as a no-spend day (not already logged, no non-essential spend).
    enum NoSpendDayBlocker { case alreadyLogged, spentToday }

    func noSpendDayBlocker(profile: UserProfile, context: ModelContext, now: Date = Date()) -> NoSpendDayBlocker? {
        if profile.hasLoggedToday(asOf: now) { return .alreadyLogged }
        if hasNonEssentialSpending(on: now, context: context) { return .spentToday }
        return nil
    }

    /// Mark a specific day (today or yesterday) as a no-spend day — used by the "Was yesterday a
    /// win?" follow-up. Refuses anything older than yesterday or already covered by the streak.
    @discardableResult
    func logNoSpendDay(for day: Date, profile: UserProfile, context: ModelContext) -> Outcome? {
        let cal = Calendar.current
        let target = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: Date())
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
              target == today || target == yesterday else { return nil }
        if target == yesterday, let last = profile.lastNoSpendDate, cal.startOfDay(for: last) >= yesterday {
            return nil   // yesterday (or today) is already part of the streak
        }
        // Stamp the mark at the end of that day so ordering against other entries is sane.
        let stamp = target == today ? Date() : (cal.date(byAdding: .second, value: -1, to: today) ?? target)
        return logNoSpendDay(profile: profile, context: context, now: stamp)
    }

    /// Mark today as a no-spend day. Returns nil (and does nothing) if today was already logged
    /// or if non-essential spending has been logged today.
    @discardableResult
    func logNoSpendDay(profile: UserProfile, context: ModelContext, now: Date = Date()) -> Outcome? {
        guard noSpendDayBlocker(profile: profile, context: context, now: now) == nil else { return nil }
        var outcome = Outcome()
        if Calendar.current.isDateInToday(now) { NotificationManager.recordLogTime(Date()) }

        let record = todayRecord(context: context, now: now)
        record.isNoSpendDay = true

        let saving = SavingsEntry(amount: profile.dailyBudget, date: now, source: .noSpendDay,
                                  note: String(localized: "No-spend day completed!"))
        context.insert(saving)
        profile.totalSaved += saving.amount
        record.totalSaved += saving.amount

        outcome.streakOutcome = profile.reconcileStreak(asOf: now)
        let newStreak = profile.registerNoSpendDay(asOf: now) ?? profile.currentStreak
        outcome.newStreak = newStreak

        if newStreak > 0, newStreak % 7 == 0, profile.streakFreezes < Self.maxStreakFreezes {
            profile.streakFreezes += 1
            outcome.streakFreezeEarned = true
        }

        let gp = ensureGameProfile(for: profile, context: context)
        grant(.noSpendDay, to: gp, streak: newStreak, into: &outcome)

        progressQuests(in: gp, type: .noSpendDays, amount: 1, into: &outcome, streak: newStreak)
        progressQuests(in: gp, type: .savingsGoal, amount: saving.amount, into: &outcome, streak: newStreak)
        syncStreakQuests(in: gp, streak: newStreak, into: &outcome)
        advanceActiveChallenge(profile: profile, gp: gp, context: context, streak: newStreak, into: &outcome)
        checkBadges(profile: profile, gp: gp, context: context, into: &outcome)

        outcome.savedAmount = saving.amount
        outcome.totalNoSpendDays = (try? context.fetchCount(
            FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.isNoSpendDay }))) ?? 0
        outcome.reviewMilestone = ReviewPrompter.milestone(for: outcome, level: gp.currentLevel)

        save(context)
        syncWidget(profile: profile, context: context, now: now)
        refreshNotifications(profile: profile, now: now)
        return outcome
    }

    /// Record a purchase. Non-essential spending un-marks today as a no-spend day; if the user
    /// had already marked today, that mark (and its streak step + savings credit) is reverted.
    /// Returns true if a previously logged no-spend day was reverted.
    @discardableResult
    func logSpending(amount: Double, category: SpendCategory, note: String, wasImpulse: Bool,
                     profile: UserProfile?, context: ModelContext, now: Date = Date()) -> Bool {
        let log = SpendingLog(amount: amount, category: category, note: note, date: now, wasImpulse: wasImpulse)
        context.insert(log)

        let record = todayRecord(context: context, now: now)
        record.totalSpent += amount

        var reverted = false
        if !category.isEssential {
            record.isNoSpendDay = false
            if let profile, profile.hasLoggedToday(asOf: now) {
                revertTodayNoSpendMark(profile: profile, record: record, context: context, now: now)
                reverted = true
            }
        }

        save(context)
        if let profile {
            syncWidget(profile: profile, context: context, now: now)
            refreshNotifications(profile: profile, now: now)
        }
        return reverted
    }

    /// Record an impulse. Resisting one earns XP, savings, and quest/badge progress.
    @discardableResult
    func logImpulse(item: String, cost: Double, category: SpendCategory, resisted: Bool,
                    triggerNote: String, copingStrategy: String,
                    profile: UserProfile?, context: ModelContext, now: Date = Date()) -> Outcome? {
        let impulse = ImpulseLog(item: item, estimatedCost: cost, category: category,
                                 wasResisted: resisted, triggerNote: triggerNote, copingStrategy: copingStrategy)
        context.insert(impulse)

        let record = todayRecord(context: context, now: now)
        if resisted { record.impulsesResisted += 1 } else { record.impulsesGivenIn += 1 }

        guard resisted, let profile else {
            save(context)
            return nil
        }

        var outcome = Outcome()
        let saving = SavingsEntry(amount: cost, date: now, source: .impulseResisted,
                                  note: String(localized: "Resisted: \(item)"))
        context.insert(saving)
        profile.totalSaved += cost
        record.totalSaved += cost

        let gp = ensureGameProfile(for: profile, context: context)
        let streak = profile.currentStreak
        grant(.impulseResisted, to: gp, streak: streak, into: &outcome)
        progressQuests(in: gp, type: .impulseResist, amount: 1, into: &outcome, streak: streak)
        progressQuests(in: gp, type: .savingsGoal, amount: cost, into: &outcome, streak: streak)
        if profile.leakCategories.isEmpty || profile.leakCategories.contains(category.rawValue) {
            progressQuests(in: gp, type: .categoryControl, amount: 1, into: &outcome, streak: streak)
        }
        checkBadges(profile: profile, gp: gp, context: context, into: &outcome)

        save(context)
        syncWidget(profile: profile, context: context, now: now)
        return outcome
    }

    /// Toggle one of the daily wins. XP is granted once per win per day; unchecking removes the
    /// savings credit but keeps the XP.
    @discardableResult
    func toggleWin(_ win: WinItem, profile: UserProfile?, context: ModelContext, now: Date = Date()) -> Outcome? {
        let record = todayRecord(context: context, now: now)

        if let idx = record.wins.firstIndex(of: win.title) {
            record.wins.remove(at: idx)
            record.totalSaved = max(0, record.totalSaved - win.savedAmount)
            profile?.totalSaved = max(0, (profile?.totalSaved ?? 0) - win.savedAmount)
            deleteWinSavingsEntry(for: win, on: now, context: context)
            save(context)
            if let profile { syncWidget(profile: profile, context: context, now: now) }
            return nil
        }

        record.wins.append(win.title)
        record.totalSaved += win.savedAmount
        profile?.totalSaved += win.savedAmount
        context.insert(SavingsEntry(amount: win.savedAmount, date: now, source: .manual, note: win.title))

        var outcome = Outcome()
        if let profile {
            let gp = ensureGameProfile(for: profile, context: context)
            let streak = profile.currentStreak
            if !record.xpAwardedWins.contains(win.title) {
                record.xpAwardedWins.append(win.title)
                grant(.dailyWin, to: gp, streak: streak, into: &outcome)
            }
            progressQuests(in: gp, type: .savingsGoal, amount: win.savedAmount, into: &outcome, streak: streak)
            checkBadges(profile: profile, gp: gp, context: context, into: &outcome)
            syncWidget(profile: profile, context: context, now: now)
        }
        save(context)
        return outcome
    }

    /// Delete a spending entry and reverse its bookkeeping. If no non-essential spending remains
    /// for that day, the day becomes eligible for a no-spend mark again (the streak is NOT
    /// re-credited automatically). XP is never clawed back.
    func deleteSpending(_ log: SpendingLog, profile: UserProfile?, context: ModelContext) {
        let day = log.date
        let record = dayRecord(for: day, context: context)
        record?.totalSpent = max(0, (record?.totalSpent ?? 0) - log.amount)
        context.delete(log)
        if let record, !hasNonEssentialSpending(on: day, context: context) {
            record.isNoSpendDay = true
        }
        save(context)
        if let profile {
            syncWidget(profile: profile, context: context, now: Date())
            refreshNotifications(profile: profile, now: Date())
        }
    }

    /// Delete an impulse and reverse its bookkeeping. A resisted impulse also removes its savings
    /// credit (matched by day, source and amount). XP is never clawed back.
    func deleteImpulse(_ impulse: ImpulseLog, profile: UserProfile?, context: ModelContext) {
        let day = impulse.date
        let record = dayRecord(for: day, context: context)
        if impulse.wasResisted {
            record?.impulsesResisted = max(0, (record?.impulsesResisted ?? 0) - 1)
            let cal = Calendar.current
            let start = cal.startOfDay(for: day)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? day
            let amount = impulse.estimatedCost
            let descriptor = FetchDescriptor<SavingsEntry>(predicate: #Predicate {
                $0.date >= start && $0.date < end && $0.amount == amount
            })
            if let entry = ((try? context.fetch(descriptor)) ?? []).first(where: { $0.source == .impulseResisted }) {
                profile?.totalSaved = max(0, (profile?.totalSaved ?? 0) - entry.amount)
                record?.totalSaved = max(0, (record?.totalSaved ?? 0) - entry.amount)
                context.delete(entry)
            }
        } else {
            record?.impulsesGivenIn = max(0, (record?.impulsesGivenIn ?? 0) - 1)
        }
        context.delete(impulse)
        save(context)
        if let profile { syncWidget(profile: profile, context: context, now: Date()) }
    }

    /// Start a challenge (deactivating any other). Day 1 counts if today is already a no-spend day.
    func startChallenge(_ challenge: ChallengeEntry, all: [ChallengeEntry], profile: UserProfile?,
                        context: ModelContext, now: Date = Date()) {
        all.forEach { if $0.isActive { $0.isActive = false } }
        challenge.isActive = true
        challenge.isCompleted = false
        challenge.startDate = now
        challenge.completedDays = profile?.hasLoggedToday(asOf: now) == true ? 1 : 0
        challenge.lastCountedDate = challenge.completedDays > 0 ? Calendar.current.startOfDay(for: now) : nil
        save(context)
    }

    /// Wipe everything the user has built. Keeps the profile identity and onboarding answers.
    func resetAllData(profile: UserProfile?, context: ModelContext) {
        try? context.delete(model: SpendingLog.self)
        try? context.delete(model: SavingsEntry.self)
        try? context.delete(model: DailyRecord.self)
        try? context.delete(model: ImpulseLog.self)
        try? context.delete(model: ChallengeEntry.self)
        try? context.delete(model: Quest.self)
        try? context.delete(model: BadgeInstance.self)
        if let profile {
            if let gp = profile.gameProfile { context.delete(gp) }
            profile.gameProfile = nil
            profile.currentStreak = 0
            profile.longestStreak = 0
            profile.totalSaved = 0
            profile.streakFreezes = 0
            profile.lastNoSpendDate = nil
            _ = ensureGameProfile(for: profile, context: context)
        }
        save(context)
        if let profile {
            syncWidget(profile: profile, context: context, now: Date())
            refreshNotifications(profile: profile, now: Date())
        }
    }

    // MARK: - Queries used by views

    func todayRecord(context: ModelContext, now: Date = Date()) -> DailyRecord {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? now
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        if let first = existing.first {
            // Defensive dedupe: an earlier version could create two records for one day.
            for dup in existing.dropFirst() {
                first.wins = Array(Set(first.wins + dup.wins))
                first.totalSpent += dup.totalSpent
                first.totalSaved += dup.totalSaved
                first.isNoSpendDay = first.isNoSpendDay && dup.isNoSpendDay
                context.delete(dup)
            }
            return first
        }
        let record = DailyRecord(date: start, isNoSpendDay: true)
        context.insert(record)
        return record
    }

    /// The existing record for a given day, if any (never creates one).
    func dayRecord(for day: Date, context: ModelContext) -> DailyRecord? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? day
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.date >= start && $0.date < end },
                                                      sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func hasNonEssentialSpending(on day: Date, context: ModelContext) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? day
        let essentials = SpendCategory.allCases.filter(\.isEssential).map(\.rawValue)
        let descriptor = FetchDescriptor<SpendingLog>(predicate: #Predicate {
            $0.date >= start && $0.date < end
        })
        let logs = (try? context.fetch(descriptor)) ?? []
        return logs.contains { !essentials.contains($0.category.rawValue) }
    }

    // MARK: - Internals

    private func ensureGameProfile(for profile: UserProfile, context: ModelContext) -> GameProfile {
        if let gp = profile.gameProfile { return gp }
        let gp = GameProfile()
        context.insert(gp)
        profile.gameProfile = gp
        gp.quests.append(contentsOf: GameStateManager.shared.generateDailyQuests())
        gp.quests.append(GameStateManager.shared.generateWeeklyQuest())
        return gp
    }

    private func grant(_ action: XPAction, to gp: GameProfile, streak: Int, into outcome: inout Outcome) {
        let multiplier = GameStateManager.shared.calculateStreakMultiplier(streak: streak)
        let r = GameStateManager.shared.grantXP(action: action, to: gp, multiplier: multiplier)
        outcome.xpGranted += r.xpGranted
        outcome.luckyBonus = outcome.luckyBonus || r.luckyBonus
        if r.leveledUp {
            outcome.levelUp = (outcome.levelUp?.previous ?? r.previousLevel, r.newLevel)
        }
        outcome.badgesUnlocked.append(contentsOf: r.badgesUnlocked)
    }

    private func progressQuests(in gp: GameProfile, type: QuestType, amount: Double,
                                into outcome: inout Outcome, streak: Int) {
        for quest in gp.quests where quest.type == type && !quest.isCompleted && !quest.isExpired {
            quest.addProgress(amount)
            if quest.isCompleted { completeQuest(quest, in: gp, into: &outcome) }
        }
    }

    /// Streak quests track the streak length itself rather than accumulating.
    private func syncStreakQuests(in gp: GameProfile, streak: Int, into outcome: inout Outcome) {
        for quest in gp.quests where quest.type == .streakMaintain && !quest.isCompleted && !quest.isExpired {
            quest.currentProgress = min(quest.targetValue, Double(streak))
            if quest.currentProgress >= quest.targetValue {
                quest.markComplete()
                completeQuest(quest, in: gp, into: &outcome)
            }
        }
    }

    private func completeQuest(_ quest: Quest, in gp: GameProfile, into outcome: inout Outcome) {
        guard !gp.completedQuestIDs.contains(quest.id.uuidString) else { return }
        gp.completedQuestIDs.append(quest.id.uuidString)
        let r = GameStateManager.shared.grantXP(amount: quest.baseXPReward, to: gp)
        outcome.xpGranted += r.xpGranted
        if r.leveledUp { outcome.levelUp = (outcome.levelUp?.previous ?? r.previousLevel, r.newLevel) }
        outcome.badgesUnlocked.append(contentsOf: r.badgesUnlocked)
        outcome.questsCompleted.append(quest)
    }

    private func advanceActiveChallenge(profile: UserProfile, gp: GameProfile, context: ModelContext,
                                        streak: Int, into outcome: inout Outcome) {
        let descriptor = FetchDescriptor<ChallengeEntry>(predicate: #Predicate { $0.isActive && !$0.isCompleted })
        guard let challenge = (try? context.fetch(descriptor))?.first else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if let last = challenge.lastCountedDate, Calendar.current.isDate(last, inSameDayAs: today) { return }
        challenge.completedDays += 1
        challenge.lastCountedDate = today
        guard challenge.completedDays >= challenge.durationDays else { return }

        challenge.isCompleted = true
        challenge.isActive = false
        outcome.challengeCompleted = challenge
        let r = GameStateManager.shared.grantXP(action: .challengeCompleted, to: gp,
                                                multiplier: GameStateManager.shared.calculateStreakMultiplier(streak: streak))
        outcome.xpGranted += r.xpGranted
        if r.leveledUp { outcome.levelUp = (outcome.levelUp?.previous ?? r.previousLevel, r.newLevel) }
        outcome.badgesUnlocked.append(contentsOf: r.badgesUnlocked)
        progressQuests(in: gp, type: .challengeComplete, amount: 1, into: &outcome, streak: streak)
    }

    private func checkBadges(profile: UserProfile, gp: GameProfile, context: ModelContext, into outcome: inout Outcome) {
        let resisted = (try? context.fetchCount(FetchDescriptor<ImpulseLog>(predicate: #Predicate { $0.wasResisted }))) ?? 0
        let completedChallenges = (try? context.fetchCount(FetchDescriptor<ChallengeEntry>(predicate: #Predicate { $0.isCompleted }))) ?? 0
        var unlocked: [BadgeInstance] = []
        unlocked += GameStateManager.shared.checkStreakBadges(for: gp, currentStreak: profile.currentStreak)
        unlocked += GameStateManager.shared.checkSavingsBadges(for: gp, totalSaved: profile.totalSaved)
        unlocked += GameStateManager.shared.checkAchievementBadges(
            for: gp, impulseCount: resisted, completedChallenges: completedChallenges,
            consecutiveNoSpendDays: profile.currentStreak)
        outcome.badgesUnlocked.append(contentsOf: unlocked)
    }

    private func revertTodayNoSpendMark(profile: UserProfile, record: DailyRecord, context: ModelContext, now: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? now
        // Enum properties can't be used inside #Predicate; filter the day's entries in memory.
        let descriptor = FetchDescriptor<SavingsEntry>(predicate: #Predicate { $0.date >= start && $0.date < end })
        let todays = ((try? context.fetch(descriptor)) ?? []).filter { $0.source == .noSpendDay }
        for entry in todays {
            profile.totalSaved = max(0, profile.totalSaved - entry.amount)
            record.totalSaved = max(0, record.totalSaved - entry.amount)
            context.delete(entry)
        }
        profile.currentStreak = max(0, profile.currentStreak - 1)
        profile.lastNoSpendDate = profile.currentStreak > 0 ? cal.date(byAdding: .day, value: -1, to: start) : nil
        if let challenge = try? context.fetch(FetchDescriptor<ChallengeEntry>(predicate: #Predicate { $0.isActive })).first,
           let last = challenge.lastCountedDate, cal.isDate(last, inSameDayAs: now) {
            challenge.completedDays = max(0, challenge.completedDays - 1)
            challenge.lastCountedDate = nil
        }
    }

    private func deleteWinSavingsEntry(for win: WinItem, on day: Date, context: ModelContext) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? day
        let title = win.title
        let descriptor = FetchDescriptor<SavingsEntry>(predicate: #Predicate {
            $0.date >= start && $0.date < end && $0.note == title
        })
        if let entry = ((try? context.fetch(descriptor)) ?? []).first(where: { $0.source == .manual }) {
            context.delete(entry)
        }
    }

    /// v1.0 installs never stored `lastNoSpendDate`; without it a stale streak can never lapse.
    private func backfillLastNoSpendDateIfNeeded(profile: UserProfile, context: ModelContext) {
        guard profile.currentStreak > 0, profile.lastNoSpendDate == nil else { return }
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.isNoSpendDay },
                                                      sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        if let latest = (try? context.fetch(descriptor))?.first {
            profile.lastNoSpendDate = Calendar.current.startOfDay(for: latest.date)
        } else {
            profile.currentStreak = 0
        }
    }

    private func consumePendingWidgetMark() -> Date? {
        guard let d = WidgetShared.defaults, let date = d.object(forKey: WidgetShared.Key.pendingMarkDate) as? Date else { return nil }
        d.removeObject(forKey: WidgetShared.Key.pendingMarkDate)
        return date
    }

    private func syncWidget(profile: UserProfile, context: ModelContext, now: Date) {
        WidgetSync.refresh(
            totalSaved: profile.totalSaved,
            currentStreak: profile.currentStreak,
            isNoSpendDay: !hasNonEssentialSpending(on: now, context: context),
            loggedToday: profile.hasLoggedToday(asOf: now)
        )
    }

    private func refreshNotifications(profile: UserProfile, now: Date) {
        NotificationManager.shared.refreshRetentionNotifications(
            currentStreak: profile.currentStreak,
            loggedToday: profile.hasLoggedToday(asOf: now)
        )
    }

    private func save(_ context: ModelContext) {
        do { try context.save() } catch { NSLog("SpendZero: save failed: \(error)") }
    }
}
