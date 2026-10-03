import Testing
import Foundation
import UIKit
@testable import SpendZero

@MainActor
struct CrossPromoTests {
    @Test func everyLinkCarriesTheProviderAndCampaignTokens() throws {
        for app in CrossPromoApp.allCases {
            let items = try #require(URLComponents(url: app.appStoreURL, resolvingAgainstBaseURL: false)?.queryItems)
            #expect(items.contains(URLQueryItem(name: "pt", value: "117201882")), "\(app)")
            #expect(items.contains(URLQueryItem(name: "ct", value: "house-spendzero")), "\(app)")
            #expect(app.appStoreURL.path.hasSuffix("id\(app.appStoreID)"), "\(app)")
        }
    }

    @Test func installedCheckSchemesAreDeclared() {
        let declared = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String] ?? []
        for app in CrossPromoApp.allCases {
            guard let scheme = app.urlScheme else { continue }
            #expect(declared.contains(scheme), "\(scheme) missing from LSApplicationQueriesSchemes")
        }
    }

    @Test func everyAppHasItsIconAndNeverPromotesSpendZero() {
        for app in CrossPromoApp.allCases {
            #expect(UIImage(named: app.iconAsset) != nil, "\(app.iconAsset)")
            #expect(app.appStoreID != 6_761_767_438)
        }
        #expect(Set(CrossPromoApp.allCases.map(\.appStoreID)).count == CrossPromoApp.allCases.count)
    }
}
