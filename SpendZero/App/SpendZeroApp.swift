import SwiftUI
import SwiftData

@main
@MainActor  // Explicit @MainActor — satisfies Swift 6 strict concurrency for SubscriptionService calls
struct SpendZeroApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                SpendingLog.self,
                ChallengeEntry.self,
                SavingsEntry.self,
                DailyRecord.self,
                ImpulseLog.self,
                GameProfile.self,
                Quest.self,
                BadgeInstance.self
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Configure RevenueCat on the main actor (SubscriptionService is @MainActor)
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
