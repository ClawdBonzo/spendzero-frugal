import Foundation
import UserNotifications

/// Powers the "Impulse-purchase alerts" feature: a daily reminder that nudges
/// the user to pause before an impulse buy. Uses local notifications only —
/// nothing leaves the device.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    static let reminderIdentifier = "spendzero.impulse.dailyReminder"
    static let streakGuardIdentifier = "spendzero.streak.eveningGuard"
    static let lapseIdentifier = "spendzero.streak.lapseReengagement"

    /// Hour (24h) for the evening streak-protection nudge.
    static let streakGuardHour = 20

    private let messages: [(title: String, body: String)] = [
        ("Pause before you spend 🧘", "Take a breath. Is this a need or an impulse? Your streak is worth protecting."),
        ("Stay on track today 💚", "Every dollar not spent is a dollar saved. Resist the impulse and log your win."),
        ("Beat the urge ⚡️", "Impulse buys fade in minutes. Open SpendZero and remind yourself why you started."),
        ("Protect your streak 🔥", "Don't break the chain. A no-spend day keeps your momentum alive.")
    ]

    /// Ask the OS for permission. Returns whether it was granted.
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Schedule a daily impulse-control reminder at the given hour (0–23).
    func scheduleDailyReminder(hour: Int, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        let pick = messages[max(0, min(hour, messages.count - 1)) % messages.count]
        let content = UNMutableNotificationContent()
        content.title = pick.title
        content.body = pick.body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }

    // MARK: - Retention Suite

    /// Re-arm the streak-protection notifications. Safe to call on every app open and
    /// after logging a no-spend day. No-ops silently if notifications aren't authorized.
    func refreshRetentionNotifications(currentStreak: Int, loggedToday: Bool) {
        Task {
            guard await authorizationStatus() == .authorized else { return }
            scheduleStreakGuard(streak: currentStreak, loggedToday: loggedToday)
            scheduleLapseReengagement(currentStreak: currentStreak)
        }
    }

    /// Evening "don't lose your streak" nudge, armed as a one-shot for the next evening the user
    /// still needs to log (today if not logged yet and it's before the guard hour, else tomorrow).
    /// Re-armed on every activation and log, so the streak count in the text is always current.
    func scheduleStreakGuard(streak: Int, loggedToday: Bool, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.streakGuardIdentifier])
        guard streak > 0 else { return }

        let cal = Calendar.current
        var fireDate = cal.date(bySettingHour: Self.streakGuardHour, minute: 0, second: 0, of: now) ?? now
        if loggedToday || fireDate <= now {
            fireDate = cal.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Protect your \(streak)-day streak 🔥")
        content.body = String(localized: "A quick no-spend check-in keeps your momentum alive. Don't break the chain!")
        content.sound = .default

        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.streakGuardIdentifier, content: content, trigger: trigger))
    }

    /// One-shot re-engagement that fires if the user goes quiet for ~36 hours.
    /// Re-armed on each app open / log, so an active user never actually receives it.
    func scheduleLapseReengagement(currentStreak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.lapseIdentifier])

        let content = UNMutableNotificationContent()
        if currentStreak > 0 {
            content.title = "Your \(currentStreak)-day streak is waiting 🔥"
            content.body = "You haven't checked in. Log a no-spend day to keep your streak alive."
        } else {
            content.title = "Your savings are waiting 💚"
            content.body = "Jump back in — log a no-spend day and start a fresh streak today."
        }
        content.sound = .default

        // 36 hours out: long enough that a daily user never sees it, short enough to
        // catch a lapse before the streak (with freezes) is gone for good.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 36 * 3600, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.lapseIdentifier, content: content, trigger: trigger))
    }

    func cancelRetentionNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.streakGuardIdentifier, Self.lapseIdentifier]
        )
    }
}
