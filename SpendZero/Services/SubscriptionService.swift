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

    // RevenueCat / App Store product identifiers
    // These must exactly match the product IDs created in App Store Connect
    // (and mirrored in RevenueCat). Verified live in ASC on 2026-05-31.
    static let weeklyID  = "spendzero_weekly"
    static let monthlyID = "spendzero_monthly"
    static let yearlyID  = "spendzero_yearly"
    static let lifetimeID = "spendzero_lifetime"

    static let entitlementID = "pro"

    // RevenueCat Apple SDK public key (appl_ prefix is correct for iOS — NOT a test key).
    // This key is safe to ship in the binary; RevenueCat public keys are designed to be client-side.
    // Verified format: appl_XXXXXXXXXXXXXXXXXXXXXXXXXX (production Apple platform key).
    static let apiKey = "appl_ZBEApxMwqwVAVxOYLtvbaLRXxrt"

    private var availablePackages: [RevenueCat.Package] = []
    private var availableProducts: [StoreProduct] = []   // direct StoreKit fallback when RC Offering is empty

    private init() {
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
            if let current = rcOfferings.current, !current.availablePackages.isEmpty {
                availablePackages = current.availablePackages
                var options: [SubscriptionOption] = []
                for package in current.availablePackages {
                    let product = package.storeProduct
                    let productID = product.productIdentifier
                    let hasTrial = product.introductoryDiscount?.paymentMode == .freeTrial
                    options.append(SubscriptionOption(
                        id: productID,
                        title: titleForPackage(package),
                        price: product.localizedPriceString,
                        pricePerWeek: pricePerWeekFor(package),
                        period: periodLabel(for: package),
                        isBestValue: productID == Self.monthlyID,
                        hasFreeTrial: hasTrial,
                        trialDays: hasTrial ? trialDaysFor(product) : 0,
                        isLifetime: package.packageType == .lifetime || productID == Self.lifetimeID
                    ))
                }
                applySorted(options)
                if offerings.isEmpty { await fetchProductsDirectly() }
            } else {
                // RC "current" Offering missing or empty — fetch products straight from StoreKit
                // so the paywall is always purchasable (and reviewable).
                await fetchProductsDirectly()
            }
        } catch {
            errorMessage = error.localizedDescription
            await fetchProductsDirectly()
        }
    }

    /// Fallback: query StoreKit directly via RevenueCat for the known product IDs. Guarantees the
    /// paywall shows real, purchasable products even if the RevenueCat Offering isn't configured.
    private func fetchProductsDirectly() async {
        let ids = [Self.monthlyID, Self.weeklyID, Self.yearlyID, Self.lifetimeID]
        let products = await Purchases.shared.products(ids)
        availableProducts = products
        guard !products.isEmpty else {
            if offerings.isEmpty { offerings = Self.fallbackOfferings }
            return
        }
        let options = products.map { product -> SubscriptionOption in
            let id = product.productIdentifier
            let hasTrial = product.introductoryDiscount?.paymentMode == .freeTrial
            return SubscriptionOption(
                id: id,
                title: titleForProductID(id),
                price: product.localizedPriceString,
                pricePerWeek: pricePerWeekForProduct(product),
                period: periodForProductID(id),
                isBestValue: id == Self.monthlyID,
                hasFreeTrial: hasTrial,
                trialDays: hasTrial ? trialDaysFor(product) : 0,
                isLifetime: id == Self.lifetimeID
            )
        }
        applySorted(options)
    }

    private func applySorted(_ options: [SubscriptionOption]) {
        let sortOrder = [Self.monthlyID, Self.weeklyID, Self.yearlyID, Self.lifetimeID]
        let sorted = options.sorted { a, b in
            (sortOrder.firstIndex(of: a.id) ?? 99) < (sortOrder.firstIndex(of: b.id) ?? 99)
        }
        if !sorted.isEmpty { offerings = sorted }
    }

    private func titleForProductID(_ id: String) -> String {
        if id.contains("lifetime") { return "Lifetime" }
        if id.contains("yearly") || id.contains("annual") { return "Yearly" }
        if id.contains("monthly") { return "Monthly" }
        if id.contains("weekly") { return "Weekly" }
        return "Premium"
    }
    private func periodForProductID(_ id: String) -> String {
        if id.contains("lifetime") { return "one-time" }
        if id.contains("yearly") || id.contains("annual") { return "per year" }
        if id.contains("monthly") { return "per month" }
        if id.contains("weekly") { return "per week" }
        return ""
    }
    private func pricePerWeekForProduct(_ product: StoreProduct) -> String {
        let id = product.productIdentifier
        if id.contains("lifetime") { return "forever" }
        let price = product.price as Decimal
        let weekly: Decimal
        if id.contains("yearly") || id.contains("annual") { weekly = price / 52 }
        else if id.contains("monthly") { weekly = price / 4.33 }
        else { weekly = price }
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencyCode = product.currencyCode ?? "USD"; f.maximumFractionDigits = 2
        return (f.string(from: weekly as NSDecimalNumber) ?? "$0") + "/wk"
    }

    // MARK: - Purchase

    func purchase(_ option: SubscriptionOption) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            if let package = availablePackages.first(where: { $0.storeProduct.productIdentifier == option.id }) {
                let result = try await Purchases.shared.purchase(package: package)
                if result.userCancelled { return false }
                isPremium = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
                return isPremium
            } else if let product = availableProducts.first(where: { $0.productIdentifier == option.id }) {
                let result = try await Purchases.shared.purchase(product: product)
                if result.userCancelled { return false }
                isPremium = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
                return isPremium
            } else {
                errorMessage = "Product not available"
                return false
            }
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
        } catch {}
    }

    // MARK: - Helpers

    private func titleForPackage(_ package: RevenueCat.Package) -> String {
        switch package.packageType {
        case .weekly:   return "Weekly"
        case .monthly:  return "Monthly"
        case .annual:   return "Yearly"
        case .lifetime: return "Lifetime"
        default:
            let id = package.storeProduct.productIdentifier
            if id.contains("lifetime") { return "Lifetime" }
            if id.contains("yearly") || id.contains("annual") { return "Yearly" }
            if id.contains("monthly") { return "Monthly" }
            if id.contains("weekly") { return "Weekly" }
            return package.storeProduct.localizedTitle
        }
    }

    private func periodLabel(for package: RevenueCat.Package) -> String {
        switch package.packageType {
        case .weekly:   return "per week"
        case .monthly:  return "per month"
        case .annual:   return "per year"
        case .lifetime: return "one-time"
        default:
            let id = package.storeProduct.productIdentifier
            if id.contains("lifetime") { return "one-time" }
            if id.contains("yearly") || id.contains("annual") { return "per year" }
            if id.contains("monthly") { return "per month" }
            if id.contains("weekly") { return "per week" }
            return ""
        }
    }

    private func pricePerWeekFor(_ package: RevenueCat.Package) -> String {
        let price = package.storeProduct.price as Decimal
        let weekly: Decimal
        switch package.packageType {
        case .weekly:   weekly = price
        case .monthly:  weekly = price / 4.33
        case .annual:   weekly = price / 52
        case .lifetime: return "forever"
        default:
            let id = package.storeProduct.productIdentifier
            if id.contains("lifetime") { return "forever" }
            if id.contains("yearly") || id.contains("annual") { weekly = price / 52 }
            else if id.contains("monthly") { weekly = price / 4.33 }
            else { weekly = price }
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = package.storeProduct.currencyCode ?? "USD"
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: weekly as NSDecimalNumber) ?? "$0"
        return "\(formatted)/wk"
    }

    private func trialDaysFor(_ product: StoreProduct) -> Int {
        guard let intro = product.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return 0 }
        switch intro.subscriptionPeriod.unit {
        case .day:   return intro.subscriptionPeriod.value
        case .week:  return intro.subscriptionPeriod.value * 7
        case .month: return intro.subscriptionPeriod.value * 30
        case .year:  return intro.subscriptionPeriod.value * 365
        @unknown default: return 0
        }
    }

    // MARK: - Fallback Offerings
    // Shown while RevenueCat loads. Matches exact pricing & trial config.

    private static let fallbackOfferings: [SubscriptionOption] = [
        SubscriptionOption(
            id: monthlyID,
            title: "Monthly",
            price: "$7.99",
            pricePerWeek: "$1.84/wk",
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
            hasFreeTrial: false,
            trialDays: 0
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
            trialDays: 0,
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
