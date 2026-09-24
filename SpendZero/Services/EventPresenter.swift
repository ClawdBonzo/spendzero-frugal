import SwiftUI

/// App-wide queue for gamification feedback (toasts, level-ups, badge unlocks).
/// Any view can `present(outcome)`; `MainTabView` renders the overlays once for all tabs.
@MainActor
@Observable
final class EventPresenter {
    static let shared = EventPresenter()
    private init() {}

    struct Toast: Identifiable {
        let id = UUID()
        let event: GameEventType
    }

    /// Everything the "day sealed" moment needs to celebrate a no-spend day.
    struct DaySealed: Identifiable {
        let id = UUID()
        let streak: Int
        let previousStreak: Int
        let xp: Int
        let saved: Double
        let lucky: Bool
        let freezeEarned: Bool
        let questsCompleted: [String]
        let challengeCompleted: String?
        let totalNoSpendDays: Int
    }

    var toast: Toast?
    var levelUp: (previous: Int, new: Int, rank: LevelRank)?
    var badgeUnlock: BadgeInstance?
    var daySealed: DaySealed?
    /// Incremented when MainTabView should show the system rating prompt.
    var reviewRequest = 0
    private(set) var reviewMilestoneToAsk: String?

    private var toastQueue: [GameEventType] = []
    private var badgeQueue: [BadgeInstance] = []
    private var pendingLevelUp: (previous: Int, new: Int, rank: LevelRank)?
    private var pendingReviewMilestone: String?

    private var isIdle: Bool { daySealed == nil && levelUp == nil && badgeUnlock == nil && badgeQueue.isEmpty }

    /// Turn an engine outcome into the right sequence of feedback.
    func present(_ outcome: ProgressEngine.Outcome, primary: GameEventType?, rank: LevelRank?) {
        if let m = outcome.reviewMilestone, ReviewPrompter.canAsk() { pendingReviewMilestone = m }

        // A freshly logged no-spend day gets the full "day sealed" moment, which shows the XP,
        // savings, quests, freeze and lucky bonus itself — so those don't also become toasts.
        if case .nospendDayRecorded = primary, let streak = outcome.newStreak {
            daySealed = DaySealed(
                streak: streak,
                previousStreak: max(0, streak - 1),
                xp: outcome.xpGranted,
                saved: outcome.savedAmount,
                lucky: outcome.luckyBonus,
                freezeEarned: outcome.streakFreezeEarned,
                questsCompleted: outcome.questsCompleted.map(\.displayTitle),
                challengeCompleted: outcome.challengeCompleted.map { String(localized: String.LocalizationValue($0.title)) },
                totalNoSpendDays: outcome.totalNoSpendDays)
            if case .frozen(let days) = outcome.streakOutcome { toastQueue.append(.streakFrozen(daysUsed: days)) }
            if let lu = outcome.levelUp, let rank { pendingLevelUp = (lu.previous, lu.new, rank) }
            badgeQueue.append(contentsOf: outcome.badgesUnlocked)
            return
        }

        if let primary { enqueue(primary) }
        if outcome.luckyBonus { enqueue(.luckyBonus(xp: outcome.xpGranted)) }
        for quest in outcome.questsCompleted {
            enqueue(.questComplete(title: quest.displayTitle, xp: quest.baseXPReward))
        }
        if let challenge = outcome.challengeCompleted {
            // Seeded challenge titles are keys in Localizable.strings; custom titles fall through unchanged.
            enqueue(.challengeComplete(title: String(localized: String.LocalizationValue(challenge.title)),
                                       xp: XPAction.challengeCompleted.baseXP))
        }
        if outcome.streakFreezeEarned { enqueue(.streakFreezeEarned) }
        if case .frozen(let days) = outcome.streakOutcome { enqueue(.streakFrozen(daysUsed: days)) }

        if let lu = outcome.levelUp, let rank { levelUp = (lu.previous, lu.new, rank) }
        badgeQueue.append(contentsOf: outcome.badgesUnlocked)
        showNextBadgeIfIdle()
        askForReviewIfIdle()
    }

    func dismissDaySealed() {
        daySealed = nil
        if let lu = pendingLevelUp { levelUp = lu; pendingLevelUp = nil }
        showNextBadgeIfIdle()
        showNextToastIfIdle()
        askForReviewIfIdle()
    }

    /// Called by MainTabView once it has shown the system prompt.
    func didRequestReview() {
        if let m = reviewMilestoneToAsk { ReviewPrompter.recordAsk(milestone: m) }
        reviewMilestoneToAsk = nil
    }

    private func askForReviewIfIdle() {
        guard isIdle, let m = pendingReviewMilestone else { return }
        pendingReviewMilestone = nil
        reviewMilestoneToAsk = m
        reviewRequest += 1
    }

    func enqueue(_ event: GameEventType) {
        toastQueue.append(event)
        showNextToastIfIdle()
    }

    func dismissToast() {
        toast = nil
        showNextToastIfIdle()
    }

    func dismissLevelUp() {
        levelUp = nil
        showNextBadgeIfIdle()
        askForReviewIfIdle()
    }

    func dismissBadge() {
        badgeUnlock = nil
        showNextBadgeIfIdle()
        askForReviewIfIdle()
    }

    private func showNextToastIfIdle() {
        guard toast == nil, !toastQueue.isEmpty else { return }
        toast = Toast(event: toastQueue.removeFirst())
    }

    private func showNextBadgeIfIdle() {
        guard daySealed == nil, levelUp == nil, badgeUnlock == nil, !badgeQueue.isEmpty else { return }
        badgeUnlock = badgeQueue.removeFirst()
    }
}
