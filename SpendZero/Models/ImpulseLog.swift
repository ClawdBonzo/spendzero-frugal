import Foundation
import SwiftData

@Model
final class ImpulseLog {
    var id: UUID
    var item: String
    var estimatedCost: Double
    var category: SpendCategory
    var wasResisted: Bool
    var date: Date
    var triggerNote: String
    var copingStrategy: String

    init(
        item: String,
        estimatedCost: Double,
        category: SpendCategory,
        wasResisted: Bool,
        triggerNote: String = "",
        copingStrategy: String = ""
    ) {
        self.id = UUID()
        self.item = item
        self.estimatedCost = estimatedCost
        self.category = category
        self.wasResisted = wasResisted
        self.date = Date()
        self.triggerNote = triggerNote
        self.copingStrategy = copingStrategy
    }
}
