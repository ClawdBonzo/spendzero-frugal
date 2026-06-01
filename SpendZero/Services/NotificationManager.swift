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
}
