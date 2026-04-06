import Foundation
import SwiftData

@Model
final class DailyRecord {
    var id: UUID
    var date: Date
    var isNoSpendDay: Bool
    var totalSpent: Double
    var totalSaved: Double
    var impulsesResisted: Int
    var impulsesGivenIn: Int
    var mood: DailyMood
    var wins: [String]
    var notes: String

    init(
        date: Date = Date(),
        isNoSpendDay: Bool = true
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.isNoSpendDay = isNoSpendDay
        self.totalSpent = 0
        self.totalSaved = 0
        self.impulsesResisted = 0
        self.impulsesGivenIn = 0
        self.mood = .neutral
        self.wins = []
        self.notes = ""
    }
}

enum DailyMood: String, Codable, CaseIterable {
    case great = "Great"
    case good = "Good"
    case neutral = "Neutral"
    case tough = "Tough"
    case struggling = "Struggling"

    var emoji: String {
        switch self {
        case .great: return "🔥"
        case .good: return "😊"
        case .neutral: return "😐"
        case .tough: return "😓"
        case .struggling: return "😫"
        }
    }
}
