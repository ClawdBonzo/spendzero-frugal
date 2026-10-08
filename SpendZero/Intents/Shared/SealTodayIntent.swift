import Foundation
import AppIntents
import ActivityKit
import WidgetKit

// Compiled into BOTH the app and the widget extension (see project.yml).

/// "Seal today": marks today as a no-spend day from Control Center, the Lock Screen, the Action
/// button, the interactive widget coin, the Live Activity button, or Siri.
///
/// Why `LiveActivityIntent`: an intent with this conformance is always performed in the APP's
/// process (the system launches the app in the background if needed), even when the button that
/// triggered it lives in the widget extension. That lets the mark go straight through
/// `IntentBridge.markNoSpendDay` -> `AppDelegate.markNoSpendDay` -> `ProgressEngine.logNoSpendDay`,
/// with streak, XP, quests, badges, the widget snapshot and notifications all updated together,
/// and without opening the app. If the handler is somehow missing (the intent ran in the
/// extension), it falls back to the existing App Group "pending mark" path the app applies on
/// next activation (same as `MarkNoSpendDayIntent`).
struct SealTodayIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Seal Today"
    static var description = IntentDescription("Seals today as a no-spend day and extends your streak, without opening SpendZero.")
    static var openAppWhenRun = false
    static var isDiscoverable = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let dialog: IntentDialog
        var sealedStreak: Int?

        if let handler = IntentBridge.markNoSpendDay {
            switch handler(now) {
            case .marked(let streak):
                sealedStreak = streak
                SealStatus.record(sealed: true, blocked: false, now: now)
                dialog = "Today is sealed. You're on a \(streak)-day streak."
            case .alreadyLogged:
                sealedStreak = WidgetShared.defaults?.integer(forKey: WidgetShared.Key.currentStreak)
                SealStatus.record(sealed: true, blocked: false, now: now)
                dialog = "Today is already sealed. Nice work."
            case .spentToday:
                SealStatus.record(sealed: false, blocked: true, now: now)
                dialog = "You logged spending today, so today can't be sealed."
            case .noProfile:
                dialog = "Open SpendZero to finish setting up first."
            }
        } else if let d = WidgetShared.defaults {
            // Extension-process fallback: leave a pending mark and update the snapshot optimistically.
            if SealStatus.isSealed(on: now) {
                dialog = "Today is already sealed."
            } else {
                let streak = d.integer(forKey: WidgetShared.Key.currentStreak) + 1
                d.set(now, forKey: WidgetShared.Key.pendingMarkDate)
                d.set(true, forKey: WidgetShared.Key.loggedToday)
                d.set(streak, forKey: WidgetShared.Key.currentStreak)
                SealStatus.record(sealed: true, blocked: false, now: now)
                sealedStreak = streak
                dialog = "Today is sealed."
            }
        } else {
            dialog = "Open SpendZero to seal today."
        }

        if let sealedStreak { await SealTodayActivity.endAll(sealedStreak: sealedStreak, now: now) }
        ControlCenter.shared.reloadControls(ofKind: SealTodayControlKind.kind)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: dialog)
    }
}

/// The Control Center / Lock Screen / Action button control's kind (shared so the app can reload it).
enum SealTodayControlKind {
    static let kind = "com.clawdbonzo.SpendZero.SealTodayControl"
}
