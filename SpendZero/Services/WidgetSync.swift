import Foundation
import SwiftData
import WidgetKit

/// Writes a small snapshot of the user's progress into the shared App Group
/// container so the Home Screen widget can display real, up-to-date data.
enum WidgetSync {
    static let appGroupID = "group.com.clawdbonzo.SpendZero"

    enum Key {
        static let totalSaved    = "widget.totalSaved"
        static let currentStreak = "widget.currentStreak"
        static let isNoSpendDay  = "widget.isNoSpendDay"
    }

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// Push the latest progress to the widget. Safe to call frequently.
    @MainActor
    static func refresh(profile: UserProfile?, context: ModelContext) {
        guard let profile, let defaults else { return }

        // A "no-spend day" = no spending logged for today.
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<SpendingLog>(
            predicate: #Predicate { $0.date >= startOfToday }
        )
        let spentToday = (try? context.fetch(descriptor))?.isEmpty == false

        defaults.set(profile.totalSaved, forKey: Key.totalSaved)
        defaults.set(profile.currentStreak, forKey: Key.currentStreak)
        defaults.set(!spentToday, forKey: Key.isNoSpendDay)

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Convenience that fetches the current profile from the context first.
    @MainActor
    static func refresh(context: ModelContext) {
        let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first
        refresh(profile: profile ?? nil, context: context)
    }
}
