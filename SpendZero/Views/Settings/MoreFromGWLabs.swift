import StoreKit
import SwiftUI
import UIKit

// MARK: - Apps

/// Other GW Labs apps SpendZero recommends in Settings › More from GW Labs, shown to everyone.
/// Only 4+ apps belong here (never the 12+ or 17+ ones). An app with a URL scheme is hidden once it's
/// installed; its scheme must be listed under `LSApplicationQueriesSchemes` in project.yml, or
/// `canOpenURL` always answers no.
enum CrossPromoApp: String, CaseIterable, Identifiable, Sendable {
    case lighthouse
    case wishLock
    case placesIveVisited
    case calmAnchor

    var id: String { rawValue }

    var appStoreID: Int {
        switch self {
        case .lighthouse: 6_761_791_646
        case .wishLock: 6_814_826_847
        case .placesIveVisited: 6_815_845_664
        case .calmAnchor: 6_761_788_508
        }
    }

    /// The App Store name. A product name: never translated.
    var name: String {
        switch self {
        case .lighthouse: "Lighthouse"
        case .wishLock: "WishLock"
        case .placesIveVisited: "Places I've Visited"
        case .calmAnchor: "CalmAnchor"
        }
    }

    var pitch: String {
        switch self {
        case .lighthouse:
            String(localized: "Dopamine detox and focus timer: less scrolling, fewer late-night carts.", comment: "One-line pitch for Lighthouse, a separate dopamine-detox and focus-timer app by the same developer. 'Late-night carts' = online shopping carts filled while scrolling at night.")
        case .wishLock:
            String(localized: "Pick one wish and practice it daily, like the thing you're saving for.", comment: "One-line pitch for WishLock, a separate manifestation journal app by the same developer: you choose one wish and practice it on a schedule.")
        case .placesIveVisited:
            String(localized: "Color in every country you've been to, then save for the next one.", comment: "One-line pitch for Places I've Visited, a separate travel-map app by the same developer.")
        case .calmAnchor:
            String(localized: "Breathing and grounding for anxious moments, money worries included.", comment: "One-line pitch for CalmAnchor, a separate calm and grounding app by the same developer. Gentle, no medical claims.")
        }
    }

    var iconAsset: String {
        switch self {
        case .lighthouse: "PromoIconLighthouse"
        case .wishLock: "PromoIconWishLock"
        case .placesIveVisited: "PromoIconPlacesIveVisited"
        case .calmAnchor: "PromoIconCalmAnchor"
        }
    }

    /// The app's own URL scheme, used only to tell whether it's installed. Lighthouse has none, so it
    /// always shows.
    var urlScheme: String? {
        switch self {
        case .lighthouse: nil
        case .wishLock: "wishlock"
        case .placesIveVisited: "placesivevisited"
        case .calmAnchor: "calmanchor"
        }
    }

    /// GW Labs' App Analytics provider token.
    static let providerToken = "117201882"
    /// App Analytics campaign, so installs from SpendZero show up as their own source.
    static let campaignToken = "house-spendzero"

    /// The product page with the provider and campaign tokens: the fallback when the in-app page can't load.
    var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/apple-store/id\(appStoreID)?pt=\(Self.providerToken)&ct=\(Self.campaignToken)&mt=8")
            ?? URL(fileURLWithPath: "/")
    }

    @MainActor
    var isInstalled: Bool {
        guard let urlScheme, let url = URL(string: "\(urlScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// The apps to show: every one that isn't on this iPhone yet.
    @MainActor
    static var notInstalled: [CrossPromoApp] { allCases.filter { !$0.isInstalled } }
}

// MARK: - Opening the App Store

/// Shows the app's App Store page in a sheet (`SKStoreProductViewController`) with the campaign and
/// provider tokens, so the user never leaves SpendZero. Falls back to the App Store link (same tokens)
/// when there's nothing to present from or the page fails to load.
@MainActor
enum AppStorePage {
    static func open(_ app: CrossPromoApp) {
        guard let presenter = topViewController() else {
            UIApplication.shared.open(app.appStoreURL)
            return
        }
        let store = SKStoreProductViewController()
        store.delegate = Dismisser.shared
        presenter.present(store, animated: true)
        let parameters: [String: Any] = [
            SKStoreProductParameterITunesItemIdentifier: NSNumber(value: app.appStoreID),
            SKStoreProductParameterProviderToken: CrossPromoApp.providerToken,
            SKStoreProductParameterCampaignToken: CrossPromoApp.campaignToken
        ]
        store.loadProduct(withParameters: parameters) { loaded, _ in
            guard !loaded else { return }
            DispatchQueue.main.async {
                store.dismiss(animated: true) { UIApplication.shared.open(app.appStoreURL) }
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private final class Dismisser: NSObject, SKStoreProductViewControllerDelegate {
        static let shared = Dismisser()

        func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
            viewController.dismiss(animated: true)
        }
    }
}

// MARK: - Row

/// One Settings row: icon, name, one-line pitch and the external-link arrow.
struct CrossPromoRow: View {
    let app: CrossPromoApp

    var body: some View {
        Button {
            HapticManager.shared.trigger(.buttonTap)
            AppStorePage.open(app)
        } label: {
            HStack(spacing: 12) {
                Image(app.iconAsset)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: app.name)
                        .font(.app(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(verbatim: app.pitch)
                        .font(.app(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .foregroundColor(AppTheme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
        .accessibilityHint(Text("Opens the App Store page"))
        .accessibilityIdentifier("crossPromo-\(app.rawValue)")
    }
}
