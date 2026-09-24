import Foundation
import RevenueCat
import StoreKit

@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    var isPremium = false
    var offerings: [SubscriptionOption] = []
    var isLoading = false
    var errorMessage: String?

    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }
    var loadState: LoadState = .idle

    enum PurchaseResult: Equatable { case success, cancelled, failed(String) }
    enum RestoreResult: Equatable { case restored, nothingToRestore, failed(String) }

    #if DEBUG
    /// Demo/screenshot builds can force premium on; entitlement refreshes won't override it.
    var debugForcePremium = false
    #endif

    /// syncPurchases is rate-limited by RevenueCat; run the safety net at most once per launch.
    private var didSyncPurchases = false

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

    private init() {}

    // MARK: - Configure

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)
        Task {
            await checkEntitlementStatus()
            await fetchOfferings()
        }
        // Keep `isPremium` live: expiry, refunds, billing-retry and purchases made on another
        // device all arrive here without waiting for the next cold launch.
        Task {
            for await info in Purchases.shared.customerInfoStream {
                apply(info)
            }
        }
    }

    private func apply(_ info: CustomerInfo) {
        #if DEBUG
        if debugForcePremium { isPremium = true; return }
        #endif
        isPremium = Self.hasAccess(info)
    }

    /// Entitlement first; fall back to product-level evidence so a user who paid is never locked
    /// out because the entitlement mapping in RevenueCat drifted.
    private static let ownProductIDs: Set<String> = [weeklyID, monthlyID, yearlyID, lifetimeID]

    /// True if StoreKit holds a verified, unrevoked, unexpired transaction for one of our products.
    private static func ownsVerifiedEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, ownProductIDs.contains(t.productID), t.revocationDate == nil {
                if let exp = t.expirationDate, exp < Date() { continue }
                return true
            }
        }
        return false
    }

    private static func hasAccess(_ info: CustomerInfo) -> Bool {
        if info.entitlements[entitlementID]?.isActive == true { return true }
        let ids: Set<String> = [weeklyID, monthlyID, yearlyID]
        if !info.activeSubscriptions.isDisjoint(with: ids) { return true }
        return info.nonSubscriptions.contains { $0.productIdentifier == lifetimeID }
    }

    // MARK: - Fetch Offerings

    func fetchOfferings() async {
        if loadState == .loading { return }
        loadState = .loading
        errorMessage = nil
        do {
            let rcOfferings = try await Purchases.shared.offerings()
            if let current = rcOfferings.current, !current.availablePackages.isEmpty {
                availablePackages = current.availablePackages
                availableProducts = []
                let products = current.availablePackages.map(\.storeProduct)
                let eligible = await trialEligibility(for: products)
                let options = current.availablePackages.map { package -> SubscriptionOption in
                    let product = package.storeProduct
                    return makeOption(product: product,
                                      title: titleForPackage(package),
                                      period: periodLabel(for: package),
                                      pricePerWeek: pricePerWeekFor(package),
                                      isLifetime: package.packageType == .lifetime || product.productIdentifier == Self.lifetimeID,
                                      trialEligible: eligible.contains(product.productIdentifier))
                }
                applySorted(options)
            } else {
                // RC "current" Offering missing or empty — fetch products straight from StoreKit
                // so the paywall is always purchasable (and reviewable).
                await fetchProductsDirectly()
            }
        } catch {
            await fetchProductsDirectly(fallbackError: error.localizedDescription)
        }
        loadState = offerings.isEmpty ? .failed(errorMessage ?? String(localized: "Couldn't load plans.")) : .loaded
    }

    /// Fallback: query StoreKit directly via RevenueCat for the known product IDs.
    private func fetchProductsDirectly(fallbackError: String? = nil) async {
        let ids = [Self.monthlyID, Self.weeklyID, Self.yearlyID, Self.lifetimeID]
        let products = await Purchases.shared.products(ids)
        availableProducts = products
        availablePackages = []
        guard !products.isEmpty else {
            errorMessage = fallbackError ?? String(localized: "Plans aren't available right now.")
            return
        }
        let eligible = await trialEligibility(for: products)
        let options = products.map { product in
            let id = product.productIdentifier
            return makeOption(product: product,
                              title: titleForProductID(id),
                              period: periodForProductID(id),
                              pricePerWeek: pricePerWeekForProduct(product),
                              isLifetime: id == Self.lifetimeID,
                              trialEligible: eligible.contains(id))
        }
        applySorted(options)
    }

    /// Product IDs whose intro offer this Apple ID is actually eligible for. A product with an
    /// intro offer the user already consumed must NOT be advertised as a free trial.
    private func trialEligibility(for products: [StoreProduct]) async -> Set<String> {
        let withIntro = products.filter { $0.introductoryDiscount?.paymentMode == .freeTrial }
        guard !withIntro.isEmpty else { return [] }
        let ids = withIntro.map(\.productIdentifier)
        let statuses = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: ids)
        return Set(statuses.compactMap { id, status in status.status == .eligible ? id : nil })
    }

    private func makeOption(product: StoreProduct, title: String, period: String, pricePerWeek: String,
                            isLifetime: Bool, trialEligible: Bool) -> SubscriptionOption {
        let id = product.productIdentifier
        let hasTrial = trialEligible && product.introductoryDiscount?.paymentMode == .freeTrial
        return SubscriptionOption(
            id: id,
            title: title,
            price: product.localizedPriceString,
            pricePerWeek: pricePerWeek,
            period: period,
            isBestValue: id == Self.yearlyID,
            hasFreeTrial: hasTrial,
            trialDays: hasTrial ? trialDaysFor(product) : 0,
            isLifetime: isLifetime,
            weeklyEquivalent: weeklyEquivalentFor(productID: id, price: product.price as Decimal)
        )
    }

    private func applySorted(_ options: [SubscriptionOption]) {
        let sortOrder = [Self.monthlyID, Self.weeklyID, Self.yearlyID, Self.lifetimeID]
        let sorted = options.sorted { a, b in
            (sortOrder.firstIndex(of: a.id) ?? 99) < (sortOrder.firstIndex(of: b.id) ?? 99)
        }
        if !sorted.isEmpty { offerings = sorted }
    }

    private func titleForProductID(_ id: String) -> String {
        if id.contains("lifetime") { return String(localized: "Lifetime") }
        if id.contains("yearly") || id.contains("annual") { return String(localized: "Yearly") }
        if id.contains("monthly") { return String(localized: "Monthly") }
        if id.contains("weekly") { return String(localized: "Weekly") }
        return String(localized: "Premium")
    }
    private func periodForProductID(_ id: String) -> String {
        if id.contains("lifetime") { return String(localized: "one-time") }
        if id.contains("yearly") || id.contains("annual") { return String(localized: "per year") }
        if id.contains("monthly") { return String(localized: "per month") }
        if id.contains("weekly") { return String(localized: "per week") }
        return ""
    }
    /// Normalized weekly cost for a product, used to compute "Save X%" anchoring.
    private func weeklyEquivalentFor(productID id: String, price: Decimal) -> Double? {
        let p = NSDecimalNumber(decimal: price).doubleValue
        if id.contains("lifetime") { return nil }
        if id.contains("yearly") || id.contains("annual") { return p / 52.0 }
        if id.contains("monthly") { return p / 4.33 }
        if id.contains("weekly") { return p }
        return nil
    }

    private func pricePerWeekForProduct(_ product: StoreProduct) -> String {
        let id = product.productIdentifier
        if id.contains("lifetime") { return String(localized: "forever") }
        let price = product.price as Decimal
        let weekly: Decimal
        if id.contains("yearly") || id.contains("annual") { weekly = price / 52 }
        else if id.contains("monthly") { weekly = price / 4.33 }
        else { weekly = price }
        let f = NumberFormatter(); f.numberStyle = .currency
        f.currencyCode = product.currencyCode ?? "USD"; f.maximumFractionDigits = 2
        let formatted = f.string(from: weekly as NSDecimalNumber) ?? "$0"
        return String(localized: "\(formatted)/wk")
    }

    // MARK: - Purchase

    func purchase(_ option: SubscriptionOption) async -> PurchaseResult {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result: PurchaseResultData
            if let package = availablePackages.first(where: { $0.storeProduct.productIdentifier == option.id }) {
                result = try await Purchases.shared.purchase(package: package)
            } else if let product = availableProducts.first(where: { $0.productIdentifier == option.id }) {
                result = try await Purchases.shared.purchase(product: product)
            } else {
                let msg = String(localized: "That plan isn't available right now. Please try again.")
                errorMessage = msg
                return .failed(msg)
            }
            if result.userCancelled { return .cancelled }
            apply(result.customerInfo)
            if isPremium { return .success }
            // The App Store charged them but RevenueCat didn't grant access — never strand a payer.
            isPremium = true
            NSLog("SpendZero: purchase of \(option.id) succeeded but no entitlement was active")
            return .success
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch {
            errorMessage = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore

    func restorePurchases() async -> RestoreResult {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return isPremium ? .restored : .nothingToRestore
        } catch {
            errorMessage = error.localizedDescription
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Check Status

    func checkEntitlementStatus() async {
        #if DEBUG
        if debugForcePremium { isPremium = true; return }
        #endif
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }

        // Safety net for a purchase RevenueCat never saw (receipt not posted). Ask StoreKit 2
        // first — silently, no sign-in — and only sync when this Apple ID really owns something:
        // syncPurchases can trigger an App Store sign-in sheet when there's nothing to sync.
        // A verified StoreKit entitlement also grants access directly, so a payer is never locked out.
        if !isPremium, !didSyncPurchases {
            didSyncPurchases = true
            if await Self.ownsVerifiedEntitlement() {
                if let info = try? await Purchases.shared.syncPurchases() { apply(info) }
                if !isPremium { isPremium = true }
            }
        }
    }

    // MARK: - Helpers

    private func titleForPackage(_ package: RevenueCat.Package) -> String {
        switch package.packageType {
        case .weekly:   return String(localized: "Weekly")
        case .monthly:  return String(localized: "Monthly")
        case .annual:   return String(localized: "Yearly")
        case .lifetime: return String(localized: "Lifetime")
        default:
            return titleForProductID(package.storeProduct.productIdentifier)
        }
    }

    private func periodLabel(for package: RevenueCat.Package) -> String {
        switch package.packageType {
        case .weekly:   return String(localized: "per week")
        case .monthly:  return String(localized: "per month")
        case .annual:   return String(localized: "per year")
        case .lifetime: return String(localized: "one-time")
        default:
            return periodForProductID(package.storeProduct.productIdentifier)
        }
    }

    private func pricePerWeekFor(_ package: RevenueCat.Package) -> String {
        let price = package.storeProduct.price as Decimal
        let weekly: Decimal
        switch package.packageType {
        case .weekly:   weekly = price
        case .monthly:  weekly = price / 4.33
        case .annual:   weekly = price / 52
        case .lifetime: return String(localized: "forever")
        default:
            let id = package.storeProduct.productIdentifier
            if id.contains("lifetime") { return String(localized: "forever") }
            if id.contains("yearly") || id.contains("annual") { weekly = price / 52 }
            else if id.contains("monthly") { weekly = price / 4.33 }
            else { weekly = price }
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = package.storeProduct.currencyCode ?? "USD"
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: weekly as NSDecimalNumber) ?? "$0"
        return String(localized: "\(formatted)/wk")
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
    /// Normalized cost per week (for computing "Save X%" anchoring vs the weekly plan).
    var weeklyEquivalent: Double? = nil

    /// Call-to-action text that states exactly what tapping does.
    var ctaTitle: String {
        if hasFreeTrial { return String(localized: "Start \(trialDays)-Day Free Trial") }
        if isLifetime { return String(localized: "Buy Lifetime — \(price)") }
        return String(localized: "Subscribe — \(price) \(period)")
    }

    /// Guideline 3.1.2 disclosure: price, duration, auto-renewal, per plan.
    var disclosure: String {
        if isLifetime {
            return String(localized: "One-time payment of \(price). No subscription.")
        }
        if hasFreeTrial {
            return String(localized: "\(trialDays)-day free trial, then \(price) \(period). Auto-renews until cancelled; cancel anytime in App Store settings.")
        }
        return String(localized: "\(price) \(period), auto-renews until cancelled. Cancel anytime in App Store settings.")
    }
}
