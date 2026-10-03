import Foundation
import ActivityKit
import SwiftData
import WidgetKit

/// Starts, updates and ends the evening check-in Live Activity ("3h left to seal today").
///
/// Call `refresh(profile:context:)` whenever today's state may have changed:
///   - on launch and every return to the foreground (after `ProgressEngine.reconcileOnActivate`)
///   - after any ProgressEngine action that changes "logged today" (no-spend mark, spending,
///     deleting spending, reset)
/// It is cheap and idempotent. Rules (see `EveningCheckIn.decide`):
///   - today sealed, or non-essential spending logged today  -> end the activity
///   - at/after 6 pm (or the reminder hour if earlier), not sealed -> start it now
///   - before that, on iOS 26+                               -> schedule it for the reminder hour
///   - an activity from a previous day                        -> ended immediately (midnight rule)
/// Each activity's content goes stale at midnight; the views then show "Day closed".
@MainActor
final class LiveActivityCoordinator {
    static let shared = LiveActivityCoordinator()
    private init() {}

    /// Re-evaluates the Live Activity for `profile` against the current time.
    func refresh(profile: UserProfile?, context: ModelContext, now: Date = Date()) {
        guard let profile else { return }
        let sealed = profile.hasLoggedToday(asOf: now)
        let blocked = !sealed && ProgressEngine.shared.hasNonEssentialSpending(on: now, context: context)

        // Day-stamped status for the Control Center control and widget.
        SealStatus.record(sealed: sealed, blocked: blocked, now: now)
        ControlCenter.shared.reloadControls(ofKind: SealTodayControlKind.kind)

        apply(streak: profile.currentStreak, sealed: sealed, blocked: blocked, now: now)
    }

    /// Lower-level entry point (no SwiftData), also used by tests and debug hooks.
    func apply(streak: Int, sealed: Bool, blocked: Bool, now: Date = Date()) {
        let activities = Activity<SealTodayAttributes>.activities
        let stale = activities.filter { EveningCheckIn.isExpired(activityDay: $0.attributes.day, now: now) }
        let current = activities.filter { !EveningCheckIn.isExpired(activityDay: $0.attributes.day, now: now) }
        if !stale.isEmpty {
            Task { for a in stale { await a.end(nil, dismissalPolicy: .immediate) } }
        }

        var forceStart = false
        #if DEBUG
        forceStart = ProcessInfo.processInfo.arguments.contains("-StartLiveActivity") && !didForceDebugStart
        #endif

        let decision: EveningCheckIn.Decision
        if forceStart {
            decision = current.isEmpty ? .startNow : .update
        } else {
            decision = EveningCheckIn.decide(now: now,
                                             sealedOrBlocked: sealed || blocked,
                                             reminderHour: Self.reminderHour,
                                             hasActivityForToday: !current.isEmpty || startedToday(now),
                                             canSchedule: Self.canSchedule)
        }

        switch decision {
        case .end:
            Task { await SealTodayActivity.endAll(sealedStreak: sealed ? streak : nil, now: now) }
        case .update:
            let deadline = EveningCheckIn.deadline(for: now)
            for activity in current where activity.activityState == .active {
                var state = activity.content.state
                guard state.streak != streak else { continue }
                state.streak = streak
                Task { await activity.update(ActivityContent(state: state, staleDate: deadline)) }
            }
        case .startNow:
            start(streak: streak, at: nil, now: now)
        case .schedule(let at):
            start(streak: streak, at: at, now: now)
        case .wait:
            break
        }
        #if DEBUG
        if forceStart { didForceDebugStart = true }
        #endif
    }

    #if DEBUG
    private var didForceDebugStart = false
    #endif

    // MARK: - Internals

    private func start(streak: Int, at scheduled: Date?, now: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let deadline = EveningCheckIn.deadline(for: now)
        let windowStart = scheduled ?? now
        let attributes = SealTodayAttributes(day: Calendar.current.startOfDay(for: now))
        let state = SealTodayAttributes.ContentState(streak: streak, windowStart: windowStart,
                                                     deadline: deadline, sealed: false)
        let content = ActivityContent(state: state, staleDate: deadline, relevanceScore: 80)
        do {
            if let scheduled {
                guard #available(iOS 26.0, *) else { return }
                let hours = EveningCheckIn.hoursLeft(now: scheduled, deadline: deadline)
                let alert = AlertConfiguration(
                    title: "\(hours)h left to seal today",
                    body: "Tap Seal to lock in today as a no-spend day.",
                    sound: .default)
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil,
                                         style: .standard, alertConfiguration: alert, start: scheduled)
            } else {
                _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            }
            UserDefaults.standard.set(attributes.day, forKey: Self.startedDayKey)
        } catch {
            NSLog("SpendZero: Live Activity request failed: \(error)")
        }
    }

    /// One activity per day: if the user swiped today's away, don't bring it back on every open.
    private static let startedDayKey = "liveActivity.startedDay"

    private func startedToday(_ now: Date) -> Bool {
        guard let day = UserDefaults.standard.object(forKey: Self.startedDayKey) as? Date else { return false }
        return Calendar.current.isDate(day, inSameDayAs: now)
    }

    /// Scheduled (future-start) Live Activities arrived in iOS 26.
    private static var canSchedule: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// The user's evening reminder hour: the impulse alert time when it's enabled and set in the
    /// evening, otherwise the learned close-the-day hour the streak guard notification uses.
    static var reminderHour: Int {
        let d = UserDefaults.standard
        if d.bool(forKey: "impulseAlertsEnabled") {
            let hour = d.object(forKey: "impulseAlertHour") as? Int ?? 18
            if hour >= 17 { return hour }
        }
        return NotificationManager.learnedGuardHour
    }
}
