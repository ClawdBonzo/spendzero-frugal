import Foundation
import SwiftData

@Model
final class SpendingLog {
    var id: UUID
    var amount: Double
    var category: SpendCategory
    var note: String
    var date: Date
    var wasImpulse: Bool
    var resistedImpulse: Bool

    init(
        amount: Double,
        category: SpendCategory,
        note: String = "",
        date: Date = Date(),
        wasImpulse: Bool = false,
        resistedImpulse: Bool = false
    ) {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.wasImpulse = wasImpulse
        self.resistedImpulse = resistedImpulse
    }
}

enum SpendCategory: String, Codable, CaseIterable, Identifiable {
    case coffee = "Coffee & Drinks"
    case eatingOut = "Eating Out"
    case shopping = "Shopping"
    case subscriptions = "Subscriptions"
    case entertainment = "Entertainment"
    case groceries = "Groceries"
    case transport = "Transport"
    case clothing = "Clothing"
    case beauty = "Beauty & Care"
    case electronics = "Electronics"
    case delivery = "Food Delivery"
    case alcohol = "Alcohol"
    case snacks = "Snacks & Treats"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .eatingOut: return "fork.knife"
        case .shopping: return "bag.fill"
        case .subscriptions: return "repeat"
        case .entertainment: return "tv.fill"
        case .groceries: return "cart.fill"
        case .transport: return "car.fill"
        case .clothing: return "tshirt.fill"
        case .beauty: return "sparkles"
        case .electronics: return "desktopcomputer"
        case .delivery: return "takeoutbag.and.cup.and.straw.fill"
        case .alcohol: return "wineglass.fill"
        case .snacks: return "birthday.cake.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .coffee: return "8B4513"
        case .eatingOut: return "FF6B6B"
        case .shopping: return "FF9800"
        case .subscriptions: return "9C27B0"
        case .entertainment: return "E91E63"
        case .groceries: return "4CAF50"
        case .transport: return "2196F3"
        case .clothing: return "FF5722"
        case .beauty: return "F48FB1"
        case .electronics: return "607D8B"
        case .delivery: return "FF7043"
        case .alcohol: return "7B1FA2"
        case .snacks: return "FFC107"
        case .other: return "78909C"
        }
    }
}
