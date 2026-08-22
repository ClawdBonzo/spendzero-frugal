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
    static let morningFollowUpIdentifier = "spendzero.streak.morningFollowUp"

    /// Default hour (24h) for the evening close-the-day nudge when we haven't learned one yet.
    static let streakGuardHour = 20

    enum Category {
        static let closeDay = "spendzero.category.closeDay"
        static let yesterday = "spendzero.category.yesterday"
    }
    enum Action {
        static let markToday = "spendzero.action.markToday"
        static let markYesterday = "spendzero.action.markYesterday"
        static let logSpending = "spendzero.action.logSpending"
    }

    /// Register the action buttons that appear on the close-the-day notifications.
    nonisolated static func registerCategories() {
        let markToday = UNNotificationAction(identifier: Action.markToday,
                                             title: String(localized: "No-spend day ✓"),
                                             options: [])
        let markYesterday = UNNotificationAction(identifier: Action.markYesterday,
                                                 title: String(localized: "Yesterday was a win ✓"),
                                                 options: [])
        let spent = UNNotificationAction(identifier: Action.logSpending,
                                         title: String(localized: "I spent…"),
                                         options: [.foreground])
        let closeDay = UNNotificationCategory(identifier: Category.closeDay, actions: [markToday, spent],
                                              intentIdentifiers: [], options: [])
        let yesterday = UNNotificationCategory(identifier: Category.yesterday, actions: [markYesterday, spent],
                                               intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([closeDay, yesterday])
    }

    // MARK: - Learned logging time

    nonisolated private static let logHoursKey = "notif.recentLogHours"

    /// Remember when the user tends to close their day so the nudge lands just before it.
    nonisolated static func recordLogTime(_ date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        var hours = UserDefaults.standard.array(forKey: logHoursKey) as? [Int] ?? []
        hours.append(hour)
        UserDefaults.standard.set(Array(hours.suffix(14)), forKey: logHoursKey)
    }

    /// Median of recent log hours, clamped to the evening. Users who log in the morning still get
    /// an evening check so a forgotten day is caught before midnight.
    static var learnedGuardHour: Int {
        let hours = (UserDefaults.standard.array(forKey: logHoursKey) as? [Int] ?? []).sorted()
        guard hours.count >= 3 else { return streakGuardHour }
        let median = hours[hours.count / 2]
        return min(max(median, 17), 22)
    }

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
            scheduleMorningFollowUp(streak: currentStreak, loggedToday: loggedToday)
            scheduleLapseReengagement(currentStreak: currentStreak)
        }
    }

    /// Evening close-the-day nudge with action buttons, at the hour the user usually logs.
    /// One-shot for the next evening that still needs a log; re-armed on every activation/log.
    func scheduleStreakGuard(streak: Int, loggedToday: Bool, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.streakGuardIdentifier])

        let cal = Calendar.current
        var fireDate = cal.date(bySettingHour: Self.learnedGuardHour, minute: 0, second: 0, of: now) ?? now
        if loggedToday || fireDate <= now {
            fireDate = cal.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        let content = UNMutableNotificationContent()
        if streak > 0 {
            content.title = String(localized: "Close out day \(streak + 1)? 🔥")
            content.body = String(localized: "Did you keep your \(streak)-day streak alive today? One tap and it's logged.")
        } else {
            content.title = String(localized: "How did today go? 💚")
            content.body = String(localized: "Log a no-spend day to start your streak — one tap is all it takes.")
        }
        content.sound = .default
        content.categoryIdentifier = Category.closeDay

        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.streakGuardIdentifier, content: content, trigger: trigger))
    }

    /// If today goes unlogged, ask the next morning instead of silently breaking the streak.
    func scheduleMorningFollowUp(streak: Int, loggedToday: Bool, now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningFollowUpIdentifier])
        guard !loggedToday else { return }

        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)),
              let fireDate = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Was yesterday a no-spend day?")
        content.body = streak > 0
            ? String(localized: "You didn't log it. Tap to keep your \(streak)-day streak going.")
            : String(localized: "Tap to count it and start your streak.")
        content.sound = .default
        content.categoryIdentifier = Category.yesterday

        let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.morningFollowUpIdentifier, content: content, trigger: trigger))
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
            withIdentifiers: [Self.streakGuardIdentifier, Self.lapseIdentifier, Self.morningFollowUpIdentifier]
        )
    }
}
