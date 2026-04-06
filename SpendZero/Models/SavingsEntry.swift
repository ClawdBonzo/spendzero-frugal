import Foundation
import SwiftData

@Model
final class SavingsEntry {
    var id: UUID
    var amount: Double
    var date: Date
    var source: SavingsSource
    var note: String

    init(
        amount: Double,
        date: Date = Date(),
        source: SavingsSource,
        note: String = ""
    ) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.source = source
        self.note = note
    }
}

enum SavingsSource: String, Codable, CaseIterable {
    case noSpendDay = "No-Spend Day"
    case impulseResisted = "Impulse Resisted"
    case challengeBonus = "Challenge Bonus"
    case subscriptionCanceled = "Subscription Canceled"
    case mealPrepped = "Meal Prepped"
    case manual = "Manual Entry"

    var icon: String {
        switch self {
        case .noSpendDay: return "checkmark.seal.fill"
        case .impulseResisted: return "bolt.slash.fill"
        case .challengeBonus: return "trophy.fill"
        case .subscriptionCanceled: return "scissors"
        case .mealPrepped: return "fork.knife"
        case .manual: return "plus.circle.fill"
        }
    }
}
