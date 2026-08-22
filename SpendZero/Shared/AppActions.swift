import Foundation
import AppIntents

/// Actions that can be requested from outside the app (widgets, Siri/Shortcuts, quick actions,
/// notification buttons). Compiled into both the app and the widget extension.
enum AppAction: String {
    case markNoSpendDay = "com.clawdbonzo.SpendZero.markNoSpendDay"
    case logSpending    = "com.clawdbonzo.SpendZero.logSpending"
    case logImpulse     = "com.clawdbonzo.SpendZero.logImpulse"

    static let pendingKey = "pendingAppAction"

    /// Queue an action for the app to perform when it next becomes active.
    func enqueue() {
        UserDefaults.standard.set(rawValue, forKey: Self.pendingKey)
        NotificationCenter.default.post(name: .spendZeroPendingAction, object: nil)
    }

    static func dequeue() -> AppAction? {
        guard let raw = UserDefaults.standard.string(forKey: pendingKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        return AppAction(rawValue: raw)
    }
}

extension Notification.Name {
    static let spendZeroPendingAction = Notification.Name("spendZeroPendingAction")
}

/// How the widget/intent process hands a "mark today" request to the app's data layer.
/// The app installs a handler at launch; the widget extension has none and falls back to
/// leaving a pending mark in the App Group for the app to apply on next activation.
enum IntentBridge {
    @MainActor static var markNoSpendDay: ((Date) -> MarkResult)?

    enum MarkResult { case marked(streak: Int), alreadyLogged, spentToday, noProfile }
}

// MARK: - Mark No-Spend Day (widget button, Siri, Shortcuts)

struct MarkNoSpendDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Today a No-Spend Day"
    static var description = IntentDescription("Logs today as a no-spend day and extends your streak.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let handler = IntentBridge.markNoSpendDay {
            switch handler(Date()) {
            case .marked(let streak):
                return .result(dialog: "No-spend day logged. You're on a \(streak)-day streak.")
            case .alreadyLogged:
                return .result(dialog: "Today is already logged. Nice work.")
            case .spentToday:
                return .result(dialog: "You logged spending today, so today can't be a no-spend day.")
            case .noProfile:
                return .result(dialog: "Open SpendZero to finish setting up first.")
            }
        }

        // Widget process: leave a pending mark and optimistically update the widget snapshot.
        guard let d = WidgetShared.defaults else { return .result(dialog: "Open SpendZero to log today.") }
        if d.bool(forKey: WidgetShared.Key.loggedToday) {
            return .result(dialog: "Today is already logged.")
        }
        d.set(Date(), forKey: WidgetShared.Key.pendingMarkDate)
        d.set(true, forKey: WidgetShared.Key.loggedToday)
        d.set(d.integer(forKey: WidgetShared.Key.currentStreak) + 1, forKey: WidgetShared.Key.currentStreak)
        return .result(dialog: "No-spend day logged.")
    }
}

// MARK: - Open-the-app intents

struct LogSpendingIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Spending"
    static var description = IntentDescription("Opens SpendZero to record a purchase.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppAction.logSpending.enqueue()
        return .result()
    }
}

struct ResistImpulseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Impulse"
    static var description = IntentDescription("Opens SpendZero to record an impulse you resisted (or didn't).")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppAction.logImpulse.enqueue()
        return .result()
    }
}
