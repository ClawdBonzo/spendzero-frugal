import Foundation

/// Constants shared between the app and the widget extension (compiled into both targets).
enum WidgetShared {
    static let appGroupID = "group.com.clawdbonzo.SpendZero"
    static let widgetKind = "SpendZeroSavingsWidget"

    enum Key {
        static let totalSaved    = "widget.totalSaved"
        static let currentStreak = "widget.currentStreak"
        static let isNoSpendDay  = "widget.isNoSpendDay"
        static let loggedToday   = "widget.loggedToday"
        /// Set by the widget intent when the user marks a no-spend day from the Home Screen;
        /// the app consumes it on next activation and applies it to SwiftData.
        static let pendingMarkDate = "widget.pendingMarkDate"
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }
}
