import SwiftUI
import SwiftData

@main
@MainActor  // Explicit @MainActor — satisfies Swift 6 strict concurrency for SubscriptionService calls
struct SpendZeroApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let modelContainer: ModelContainer

    init() {
        modelContainer = SpendZeroStore.makeContainer()
        SpendZeroStore.container = modelContainer

        // Siri / Shortcuts / widget taps that run in-process apply straight to the store.
        IntentBridge.markNoSpendDay = { day in AppDelegate.markNoSpendDay(for: day) }

        // Configure RevenueCat on the main actor (SubscriptionService is @MainActor)
        SubscriptionService.shared.configure()

        #if DEBUG
        if DemoSeeder.isEnabled {
            DemoSeeder.seed(into: modelContainer.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
