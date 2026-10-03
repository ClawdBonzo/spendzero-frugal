import Foundation
import ActivityKit

// Compiled into BOTH the app and the widget extension (see project.yml). Keep this file free of
// app-only types (SwiftData models, ProgressEngine) so the extension can build it.

// MARK: - Live Activity model

/// The evening check-in Live Activity: "Xh left to seal today".
struct SealTodayAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Current streak (before today is sealed; the sealed state carries the new streak).
        var streak: Int
        /// When the countdown started (drives the progress bar).
        var windowStart: Date
        /// Midnight: the moment today can no longer be sealed.
        var deadline: Date
        /// True once today has been sealed; the activity is ended with this as its final content.
        var sealed: Bool
    }

    /// Start of the calendar day this activity is about. Activities for any other day are stale.
    var day: Date
}

// MARK: - Countdown / end-of-day rules (pure, unit tested)

enum EveningCheckIn {
    /// Opening the app at or after this hour (local) without having logged today starts the activity.
    static let openThresholdHour = 18

    /// What the coordinator should do with the Live Activity right now.
    enum Decision: Equatable {
        /// Today is sealed or can't be sealed (non-essential spending): end any activity.
        case end
        /// Inside the evening window with no activity yet: start one immediately.
        case startNow
        /// Before the evening window: schedule one to appear at this time (iOS 26+ only).
        case schedule(at: Date)
        /// An activity for today already exists (running or scheduled): just update it.
        case update
        /// Nothing to do yet (before the window and scheduling isn't available).
        case wait
    }

    /// The next local midnight after `now`: the deadline for sealing today.
    static func deadline(for now: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
    }

    /// The reminder hour, clamped to a sensible evening window (17:00–23:00).
    static func clampedReminderHour(_ hour: Int) -> Int { min(max(hour, 17), 23) }

    /// When the scheduled activity should appear today: the user's evening reminder time.
    static func scheduledStart(on now: Date, reminderHour: Int, calendar: Calendar = .current) -> Date {
        let hour = clampedReminderHour(reminderHour)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
    }

    /// When opening the app starts the activity: 6 pm, or earlier if the reminder is earlier.
    static func openWindowStart(on now: Date, reminderHour: Int, calendar: Calendar = .current) -> Date {
        let hour = min(openThresholdHour, clampedReminderHour(reminderHour))
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
    }

    /// Whole hours left to seal today, rounded up ("2h 10m" left reads as "3h left"). Zero at/after midnight.
    static func hoursLeft(now: Date, deadline: Date) -> Int {
        let seconds = deadline.timeIntervalSince(now)
        guard seconds > 0 else { return 0 }
        return Int((seconds / 3600).rounded(.up))
    }

    /// An activity belongs to a day; once that day is over it must be ended.
    static func isExpired(activityDay: Date, now: Date, calendar: Calendar = .current) -> Bool {
        !calendar.isDate(activityDay, inSameDayAs: now)
    }

    static func decide(now: Date,
                       sealedOrBlocked: Bool,
                       reminderHour: Int,
                       hasActivityForToday: Bool,
                       canSchedule: Bool,
                       calendar: Calendar = .current) -> Decision {
        if sealedOrBlocked { return .end }
        if hasActivityForToday { return .update }
        if now >= openWindowStart(on: now, reminderHour: reminderHour, calendar: calendar) {
            return now < deadline(for: now, calendar: calendar) ? .startNow : .wait
        }
        guard canSchedule else { return .wait }
        return .schedule(at: scheduledStart(on: now, reminderHour: reminderHour, calendar: calendar))
    }
}

// MARK: - "Sealed today?" status shared through the App Group

/// Day-stamped seal status, so the control and widget never show yesterday's "Sealed" after
/// midnight. Written by the app (LiveActivityCoordinator.refresh) and by SealTodayIntent.
enum SealStatus {
    enum Key {
        /// Start of the last day that was sealed.
        static let sealedDay = "seal.sealedDay"
        /// Start of the last day that had non-essential spending (can't be sealed).
        static let blockedDay = "seal.blockedDay"
    }

    static func isSealed(on now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let d = WidgetShared.defaults else { return false }
        if let day = d.object(forKey: Key.sealedDay) as? Date { return calendar.isDate(day, inSameDayAs: now) }
        // Not stamped yet (older app build): fall back to the widget snapshot flag.
        return d.bool(forKey: WidgetShared.Key.loggedToday)
    }

    static func isBlocked(on now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let day = WidgetShared.defaults?.object(forKey: Key.blockedDay) as? Date else { return false }
        return calendar.isDate(day, inSameDayAs: now)
    }

    static func record(sealed: Bool, blocked: Bool, now: Date = Date(), calendar: Calendar = .current) {
        guard let d = WidgetShared.defaults else { return }
        let today = calendar.startOfDay(for: now)
        if sealed { d.set(today, forKey: Key.sealedDay) }
        else if let day = d.object(forKey: Key.sealedDay) as? Date, calendar.isDate(day, inSameDayAs: now) {
            d.removeObject(forKey: Key.sealedDay)   // a spend reverted today's seal
        }
        if blocked { d.set(today, forKey: Key.blockedDay) }
        else { d.removeObject(forKey: Key.blockedDay) }
    }
}

// MARK: - Ending the activity (usable from the intent in either process)

enum SealTodayActivity {
    /// Ends every evening check-in activity. When `sealedStreak` is given, the activity shows a
    /// final "Day sealed" state for a short while before it is dismissed.
    static func endAll(sealedStreak: Int?, now: Date = Date()) async {
        for activity in Activity<SealTodayAttributes>.activities {
            // Only a visible activity gets the celebratory final state; a scheduled (pending) one
            // that hasn't appeared yet, or yesterday's, is simply removed.
            if let streak = sealedStreak, activity.activityState == .active,
               !EveningCheckIn.isExpired(activityDay: activity.attributes.day, now: now) {
                var state = activity.content.state
                state.streak = streak
                state.sealed = true
                let dismissAt = min(now.addingTimeInterval(15 * 60), state.deadline)
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(dismissAt))
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
