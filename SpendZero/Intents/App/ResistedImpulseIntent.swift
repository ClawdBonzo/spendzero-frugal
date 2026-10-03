import Foundation
import AppIntents
import SwiftData

// App target only: runs in the app's process (Siri/Shortcuts launch it in the background) and
// logs through ProgressEngine exactly like the Add Impulse sheet does.

/// "I resisted buying <thing>": records a resisted impulse with an optional amount.
struct ResistedImpulseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Resisted Impulse"
    static var description = IntentDescription("Records something you wanted to buy but didn't, and credits what you would have spent to your savings.")
    static var openAppWhenRun = false

    @Parameter(title: "Item", requestValueDialog: "What did you resist buying?")
    var item: String

    @Parameter(title: "Amount", description: "About how much it would have cost.",
               inclusiveRange: (0, 100_000))
    var amount: Double?

    @Parameter(title: "Category")
    var category: ImpulseCategoryAppEnum?

    static var parameterSummary: some ParameterSummary {
        Summary("I resisted buying \(\.$item) for \(\.$amount)") {
            \.$category
        }
    }

    init() {}

    init(item: String, amount: Double?, category: ImpulseCategoryAppEnum? = nil) {
        self.item = item
        self.amount = amount
        self.category = category
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $item.needsValueError("What did you resist buying?")
        }
        guard let container = SpendZeroStore.container,
              let profile = try? container.mainContext.fetch(FetchDescriptor<UserProfile>()).first else {
            return .result(dialog: "Open SpendZero to finish setting up first.")
        }
        let cost = max(0, amount ?? 0)
        let outcome = ProgressEngine.shared.logImpulse(
            item: trimmed,
            cost: cost,
            category: category?.spendCategory ?? .other,
            resisted: true,
            triggerNote: "",
            copingStrategy: "",
            profile: profile,
            context: container.mainContext
        )
        if let outcome {
            EventPresenter.shared.present(outcome, primary: .impulseResisted(xp: outcome.xpGranted),
                                          rank: profile.gameProfile?.currentRank)
        }
        if cost > 0 {
            let saved = cost.rounded() == cost ? cost.currencyFormatted : cost.currencyFormattedDecimal
            return .result(dialog: "Nice. You skipped \(trimmed) and kept \(saved).")
        }
        return .result(dialog: "Nice. You resisted \(trimmed). That's a win logged.")
    }
}

/// Impulse categories for Siri/Shortcuts. Display names reuse the existing category keys in
/// Localizable.strings (the persisted raw values), so they are already translated.
enum ImpulseCategoryAppEnum: String, AppEnum {
    case coffee, eatingOut, shopping, subscriptions, entertainment, clothing, beauty
    case electronics, delivery, alcohol, snacks, other

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"

    static var caseDisplayRepresentations: [ImpulseCategoryAppEnum: DisplayRepresentation] = [
        .coffee: "Coffee & Drinks",
        .eatingOut: "Eating Out",
        .shopping: "Shopping",
        .subscriptions: "Subscriptions",
        .entertainment: "Entertainment",
        .clothing: "Clothing",
        .beauty: "Beauty & Care",
        .electronics: "Electronics",
        .delivery: "Food Delivery",
        .alcohol: "Alcohol",
        .snacks: "Snacks & Treats",
        .other: "Other",
    ]

    var spendCategory: SpendCategory {
        switch self {
        case .coffee: .coffee
        case .eatingOut: .eatingOut
        case .shopping: .shopping
        case .subscriptions: .subscriptions
        case .entertainment: .entertainment
        case .clothing: .clothing
        case .beauty: .beauty
        case .electronics: .electronics
        case .delivery: .delivery
        case .alcohol: .alcohol
        case .snacks: .snacks
        case .other: .other
        }
    }
}
