import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    var isPremium = false
    var offerings: [SubscriptionOption] = []
    var isLoading = false

    // Placeholder RevenueCat API key — replace with your real key
    private let apiKey = "YOUR_REVENUECAT_PUBLIC_KEY"

    private init() {
        // Initialize with demo offerings
        offerings = [
            SubscriptionOption(
                id: "weekly",
                title: "Weekly",
                price: "$4.99",
                pricePerWeek: "$4.99/wk",
                period: "per week",
                isBestValue: false,
                hasFreeTrial: false
            ),
            SubscriptionOption(
                id: "annual",
                title: "Annual",
                price: "$29.99",
                pricePerWeek: "$0.58/wk",
                period: "per year",
                isBestValue: true,
                hasFreeTrial: true,
                trialDays: 3
            ),
            SubscriptionOption(
                id: "monthly",
                title: "Monthly",
                price: "$9.99",
                pricePerWeek: "$2.31/wk",
                period: "per month",
                isBestValue: false,
                hasFreeTrial: true,
                trialDays: 3
            )
        ]
    }

    func configure(withAPIKey key: String) {
        // TODO: Initialize RevenueCat with:
        // Purchases.configure(withAPIKey: key)
    }

    func purchase(_ option: SubscriptionOption) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        // TODO: Implement RevenueCat purchase
        // let result = try await Purchases.shared.purchase(package: package)
        // isPremium = result.customerInfo.entitlements["premium"]?.isActive == true

        // For now, simulate a successful purchase
        try? await Task.sleep(for: .seconds(1))
        isPremium = true
        return true
    }

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        // TODO: Implement RevenueCat restore
        try? await Task.sleep(for: .seconds(1))
        return false
    }
}

struct SubscriptionOption: Identifiable {
    let id: String
    let title: String
    let price: String
    let pricePerWeek: String
    let period: String
    let isBestValue: Bool
    let hasFreeTrial: Bool
    var trialDays: Int = 0
}
