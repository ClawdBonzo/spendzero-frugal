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

    var toast: Toast?
    var levelUp: (previous: Int, new: Int, rank: LevelRank)?
    var badgeUnlock: BadgeInstance?

    private var toastQueue: [GameEventType] = []
    private var badgeQueue: [BadgeInstance] = []

    /// Turn an engine outcome into the right sequence of feedback.
    func present(_ outcome: ProgressEngine.Outcome, primary: GameEventType?, rank: LevelRank?) {
        if let primary { enqueue(primary) }
        if outcome.luckyBonus { enqueue(.luckyBonus(xp: outcome.xpGranted)) }
        for quest in outcome.questsCompleted {
            enqueue(.questComplete(title: quest.displayTitle, xp: quest.baseXPReward))
        }
        if let challenge = outcome.challengeCompleted {
            enqueue(.challengeComplete(title: challenge.title, xp: XPAction.challengeCompleted.baseXP))
        }
        if let streak = outcome.newStreak, [7, 30, 100, 365].contains(streak) {
            enqueue(.streakMilestone(days: streak))
        }
        if outcome.streakFreezeEarned { enqueue(.streakFreezeEarned) }
        if case .frozen(let days) = outcome.streakOutcome { enqueue(.streakFrozen(daysUsed: days)) }

        if let lu = outcome.levelUp, let rank { levelUp = (lu.previous, lu.new, rank) }
        badgeQueue.append(contentsOf: outcome.badgesUnlocked)
        showNextBadgeIfIdle()
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
    }

    func dismissBadge() {
        badgeUnlock = nil
        showNextBadgeIfIdle()
    }

    private func showNextToastIfIdle() {
        guard toast == nil, !toastQueue.isEmpty else { return }
        toast = Toast(event: toastQueue.removeFirst())
    }

    private func showNextBadgeIfIdle() {
        guard levelUp == nil, badgeUnlock == nil, !badgeQueue.isEmpty else { return }
        badgeUnlock = badgeQueue.removeFirst()
    }
}
