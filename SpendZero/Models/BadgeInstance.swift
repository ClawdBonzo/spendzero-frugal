import Foundation
import SwiftData
import SwiftUI

/// An earned badge instance with metadata
@Model
final class BadgeInstance {
    var id: UUID
    var badgeID: BadgeType
    var earnedDate: Date
    var rarity: BadgeRarity

    init(badgeID: BadgeType, rarity: BadgeRarity = .common) {
        self.id = UUID()
        self.badgeID = badgeID
        self.earnedDate = Date()
        self.rarity = rarity
    }
}

// MARK: - Badge Type Enum
enum BadgeType: String, Codable, CaseIterable, Identifiable {
    // Streak badges
    case sevenDayStreak = "7-Day Streak"
    case thirtyDayStreak = "30-Day Streak"
    case hundredDayStreak = "100-Day Streak"
    case oneYearStreak = "1-Year Streak"

    // Savings milestones
    case savedFiveHundred = "$500 Saved"
    case savedOneThousand = "$1,000 Saved"
    case savedFiveThousand = "$5,000 Saved"
    case savedTenThousand = "$10,000 Saved"

    // Achievement badges
    case perfectWeek = "Perfect Week"
    case impulseExpert = "Impulse Expert"
    case challengeChampion = "Challenge Champion"
    case savingsMaster = "Savings Master"
    case speedSaver = "Speed Saver"
    case momentum = "Momentum"

    // Level badges
    case levelTen = "Level 10"
    case levelTwentyFive = "Wealth King"

    var id: String { rawValue }

    /// Display name looked up in Localizable.strings (raw values are persisted, so they stay English).
    var localizedName: String { String(localized: String.LocalizationValue(rawValue)) }

    var icon: String {
        switch self {
        case .sevenDayStreak:
            return "7.circle.fill"
        case .thirtyDayStreak:
            return "30.circle.fill"
        case .hundredDayStreak:
            return "flame.circle.fill"
        case .oneYearStreak:
            return "star.circle.fill"
        case .savedFiveHundred:
            return "dollarsign.circle.fill"
        case .savedOneThousand:
            return "banknote.fill"
        case .savedFiveThousand:
            return "crown.fill"
        case .savedTenThousand:
            return "diamond.fill"
        case .perfectWeek:
            return "checkmark.seal.fill"
        case .impulseExpert:
            return "bolt.slash.circle.fill"
        case .challengeChampion:
            return "trophy.circle.fill"
        case .savingsMaster:
            return "medal.fill"
        case .speedSaver:
            return "hare.fill"
        case .momentum:
            return "arrow.up.circle.fill"
        case .levelTen:
            return "10.circle.fill"
        case .levelTwentyFive:
            return "crown.fill"
        }
    }

    var description: String {
        switch self {
        case .sevenDayStreak:
            return String(localized: "Maintained a 7-day no-spend streak")
        case .thirtyDayStreak:
            return String(localized: "Maintained a 30-day no-spend streak")
        case .hundredDayStreak:
            return String(localized: "Maintained a 100-day no-spend streak")
        case .oneYearStreak:
            return String(localized: "Maintained a 1-year no-spend streak")
        case .savedFiveHundred:
            return String(localized: "Saved \(500.0.currencyFormatted) total")
        case .savedOneThousand:
            return String(localized: "Saved \(1000.0.currencyFormatted) total")
        case .savedFiveThousand:
            return String(localized: "Saved \(5000.0.currencyFormatted) total")
        case .savedTenThousand:
            return String(localized: "Saved \(10000.0.currencyFormatted) total")
        case .perfectWeek:
            return String(localized: "Completed 7 consecutive no-spend days")
        case .impulseExpert:
            return String(localized: "Resisted 50 total impulses")
        case .challengeChampion:
            return String(localized: "Completed 5 challenges")
        case .savingsMaster:
            return String(localized: "Achieved maximum savings goal")
        case .speedSaver:
            return String(localized: "Completed a challenge 2x faster than expected")
        case .momentum:
            return String(localized: "Increased streak by 10+ days")
        case .levelTen:
            return String(localized: "Reached Level 10")
        case .levelTwentyFive:
            return String(localized: "Reached ultimate Wealth King status")
        }
    }
}

// MARK: - Badge Rarity Enum
enum BadgeRarity: String, Codable, CaseIterable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"

    var color: Color {
        switch self {
        case .common:
            return Color(hex: "8899AA") // Muted secondary text
        case .rare:
            return Color(hex: "00E676") // Bright green
        case .epic:
            return Color(hex: "FFD740") // Gold
        case .legendary:
            return Color(hex: "FF6B9D") // Pink/magenta
        }
    }

    var backgroundColor: Color {
        switch self {
        case .common:
            return Color(hex: "8899AA").opacity(0.15)
        case .rare:
            return Color(hex: "00E676").opacity(0.15)
        case .epic:
            return Color(hex: "FFD740").opacity(0.15)
        case .legendary:
            return Color(hex: "FF6B9D").opacity(0.15)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .common:
            return Color(hex: "8899AA")
        case .rare:
            return Color(hex: "00E676")
        case .epic:
            return Color(hex: "FFD740")
        case .legendary:
            return Color(hex: "FF6B9D")
        }
    }

    var borderColor: Color {
        switch self {
        case .common:
            return Color(hex: "8899AA").opacity(0.4)
        case .rare:
            return Color(hex: "00E676").opacity(0.4)
        case .epic:
            return Color(hex: "FFD740").opacity(0.4)
        case .legendary:
            return Color(hex: "FF6B9D").opacity(0.4)
        }
    }

    var glowColor: Color {
        switch self {
        case .common:
            return .clear
        case .rare:
            return Color(hex: "00E676").opacity(0.3)
        case .epic:
            return Color(hex: "FFD740").opacity(0.3)
        case .legendary:
            return Color(hex: "FF6B9D").opacity(0.4)
        }
    }

    /// Localized display label (raw values are persisted, so they stay English).
    var label: String { String(localized: String.LocalizationValue(rawValue)) }
}
