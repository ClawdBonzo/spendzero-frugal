import Foundation
import WidgetKit

/// Writes a small snapshot of the user's progress into the shared App Group container so the
/// Home Screen widget can display real, up-to-date data. Only `ProgressEngine` calls this.
enum WidgetSync {
    @MainActor
    static func refresh(totalSaved: Double, currentStreak: Int, isNoSpendDay: Bool, loggedToday: Bool) {
        guard let defaults = WidgetShared.defaults else { return }
        defaults.set(totalSaved, forKey: WidgetShared.Key.totalSaved)
        defaults.set(currentStreak, forKey: WidgetShared.Key.currentStreak)
        defaults.set(isNoSpendDay, forKey: WidgetShared.Key.isNoSpendDay)
        defaults.set(loggedToday, forKey: WidgetShared.Key.loggedToday)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
