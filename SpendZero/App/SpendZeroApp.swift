import SwiftUI
import SwiftData

@main
@MainActor  // Explicit @MainActor — satisfies Swift 6 strict concurrency for SubscriptionService calls
struct SpendZeroApp: App {
    let modelContainer: ModelContainer

    init() {
        modelContainer = SpendZeroStore.makeContainer()

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
