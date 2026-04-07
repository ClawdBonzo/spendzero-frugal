import Foundation
import RevenueCat

@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    var isPremium = false
    var offerings: [SubscriptionOption] = []
    var isLoading = false
    var errorMessage: String?

    // RevenueCat product identifiers
    static let weeklyID = "spendzero_weekly"
    static let monthlyID = "spendzero_monthly"
    static let yearlyID = "spendzero_yearly"
    static let lifetimeID = "spendzero_lifetime"

    static let entitlementID = "pro"

    // MARK: - RevenueCat Public API Key
    static let apiKey = "appl_ZBEApxMwqwVAVxOYLtvbaLRXxrt"

    private var availablePackages: [RevenueCat.Package] = []

    private init() {
        // Fallback offerings shown before RevenueCat loads
        offerings = Self.fallbackOfferings
    }

    // MARK: - Configure

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)

        Task {
            await checkEntitlementStatus()
            await fetchOfferings()
        }
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async {
        do {
            let rcOfferings = try await Purchases.shared.offerings()
            guard let current = rcOfferings.current else {
                offerings = Self.fallbackOfferings
                return
            }

            availablePackages = current.availablePackages
            var options: [SubscriptionOption] = []

            for package in current.availablePackages {
                let product = package.storeProduct
                let option = SubscriptionOption(
                    id: product.productIdentifier,
                    title: titleForPackage(package),
                    price: product.localizedPriceString,
                    pricePerWeek: pricePerWeekFor(package),
                    period: periodLabel(for: package),
                    isBestValue: product.productIdentifier == Self.monthlyID,
                    hasFreeTrial: product.introductoryDiscount?.paymentMode == .freeTrial,
                    trialDays: trialDaysFor(product),
                    isLifetime: package.packageType == .lifetime || product.productIdentifier == Self.lifetimeID
                )
                options.append(option)
            }

            // Sort: monthly (best value) first, then weekly, yearly, lifetime
            let sortOrder = [Self.monthlyID, Self.weeklyID, Self.yearlyID, Self.lifetimeID]
            offerings = options.sorted { a, b in
                let ai = sortOrder.firstIndex(of: a.id) ?? 99
                let bi = sortOrder.firstIndex(of: b.id) ?? 99
                return ai < bi
            }
        } catch {
            errorMessage = error.localizedDescription
            offerings = Self.fallbackOfferings
        }
    }

    // MARK: - Purchase

    func purchase(_ option: SubscriptionOption) async -> Bool {
        guard let package = availablePackages.first(where: {
            $0.storeProduct.productIdentifier == option.id
        }) else {
            errorMessage = "Product not available"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                isPremium = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
                return isPremium
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
            return isPremium
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Check Status

    func checkEntitlementStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPremium = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        } catch {
            // Silently fail — will check again later
        }
    }

    // MARK: - Helpers

    private func titleForPackage(_ package: RevenueCat.Package) -> String {
        switch package.packageType {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Yearly"
        case .lifetime: return "Lifetime"
        default:
            let id = package.storeProduct.productIdentifier
            if id.contains("lifetime") { return "Lifetime" }
            return package.storeProduct.localizedTitle
        }
    }

    private func periodLabel(for package: RevenueCat.Package) -> String {
        switch package.packageType {
        case .weekly: return "per week"
        case .monthly: return "per month"
        case .annual: return "per year"
        case .lifetime: return "one-time"
        default:
            if package.storeProduct.productIdentifier.contains("lifetime") { return "one-time" }
            return ""
        }
    }

    private func pricePerWeekFor(_ package: RevenueCat.Package) -> String {
        let price = package.storeProduct.price as Decimal
        let weekly: Decimal
        switch package.packageType {
        case .weekly: weekly = price
        case .monthly: weekly = price / 4.33
        case .annual: weekly = price / 52
        case .lifetime: return "forever"
        default:
            if package.storeProduct.productIdentifier.contains("lifetime") { return "forever" }
            return ""
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: weekly as NSDecimalNumber) ?? "$0"
        return "\(formatted)/wk"
    }

    private func trialDaysFor(_ product: StoreProduct) -> Int {
        guard let intro = product.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return 0 }
        switch intro.subscriptionPeriod.unit {
        case .day: return intro.subscriptionPeriod.value
        case .week: return intro.subscriptionPeriod.value * 7
        case .month: return intro.subscriptionPeriod.value * 30
        case .year: return intro.subscriptionPeriod.value * 365
        @unknown default: return 0
        }
    }

    // MARK: - Fallback Offerings

    private static let fallbackOfferings: [SubscriptionOption] = [
        SubscriptionOption(
            id: monthlyID,
            title: "Monthly",
            price: "$9.99",
            pricePerWeek: "$2.31/wk",
            period: "per month",
            isBestValue: true,
            hasFreeTrial: true,
            trialDays: 3
        ),
        SubscriptionOption(
            id: weeklyID,
            title: "Weekly",
            price: "$4.99",
            pricePerWeek: "$4.99/wk",
            period: "per week",
            isBestValue: false,
            hasFreeTrial: false
        ),
        SubscriptionOption(
            id: yearlyID,
            title: "Yearly",
            price: "$49.99",
            pricePerWeek: "$0.96/wk",
            period: "per year",
            isBestValue: false,
            hasFreeTrial: true,
            trialDays: 3
        ),
        SubscriptionOption(
            id: lifetimeID,
            title: "Lifetime",
            price: "$79.99",
            pricePerWeek: "forever",
            period: "one-time",
            isBestValue: false,
            hasFreeTrial: false,
            isLifetime: true
        ),
    ]
}

// MARK: - Subscription Option Model

struct SubscriptionOption: Identifiable {
    let id: String
    let title: String
    let price: String
    let pricePerWeek: String
    let period: String
    let isBestValue: Bool
    let hasFreeTrial: Bool
    var trialDays: Int = 0
    var isLifetime: Bool = false
}
