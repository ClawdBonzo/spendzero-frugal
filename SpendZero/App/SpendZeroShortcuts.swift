import AppIntents

/// Surfaces the app's intents to Siri, Spotlight and the Shortcuts app with spoken phrases.
struct SpendZeroShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MarkNoSpendDayIntent(),
            phrases: [
                "Mark today a no-spend day in \(.applicationName)",
                "Log a no-spend day in \(.applicationName)",
                "I didn't spend today in \(.applicationName)",
            ],
            shortTitle: "No-Spend Day",
            systemImageName: "checkmark.seal.fill"
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
            systemImageName: "hand.raised.fill"
        )
    }
}
