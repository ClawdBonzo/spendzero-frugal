import AppIntents

/// Surfaces the app's intents to Siri, Spotlight and the Shortcuts app with spoken phrases.
/// Every phrase must contain `\(.applicationName)`. English phrases live here; translations go
/// in Resources/*.lproj/AppShortcuts.strings (keys use `${applicationName}`).
struct SpendZeroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SealTodayIntent(),
            phrases: [
                "Seal today in \(.applicationName)",
                "Seal the day in \(.applicationName)",
                "Seal my day in \(.applicationName)",
            ],
            shortTitle: "Seal Today",
            systemImageName: "checkmark.seal.fill"
        )
        AppShortcut(
            intent: MarkNoSpendDayIntent(),
            phrases: [
                "Mark today a no-spend day in \(.applicationName)",
                "Log a no-spend day in \(.applicationName)",
                "I didn't spend today in \(.applicationName)",
            ],
            shortTitle: "No-Spend Day",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: ResistedImpulseIntent(),
            phrases: [
                "I resisted buying something in \(.applicationName)",
                "I didn't buy something in \(.applicationName)",
                "Log a resisted impulse in \(.applicationName)",
            ],
            shortTitle: "I Resisted Buying…",
            systemImageName: "hand.raised.fill"
        )
        AppShortcut(
            intent: LogSpendingIntent(),
            phrases: ["Log spending in \(.applicationName)", "I spent money in \(.applicationName)"],
            shortTitle: "Log Spending",
            systemImageName: "creditcard.fill"
        )
        AppShortcut(
            intent: ResistImpulseIntent(),
            phrases: ["Log an impulse in \(.applicationName)", "I resisted an impulse in \(.applicationName)"],
            shortTitle: "Log Impulse",
            systemImageName: "hand.raised"
        )
    }
}
