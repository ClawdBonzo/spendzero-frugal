import Foundation

/// Limited-time challenges tied to the no-spend calendar. Each appears in the challenge library
/// only during its window, and App Store in-app events deep-link to it via
/// `spendzero://challenge/<id>`.
struct SeasonalChallenge: Identifiable {
    /// Deep-link key. Stable; referenced by App Store in-app events.
    let id: String
    /// Localization key; also stored as `ChallengeEntry.title`, which is how entries are matched.
    let title: String
    let description: String
    let durationDays: Int
    let difficulty: ChallengeDifficulty
    let estimatedSavings: Double
    /// The offer window for the season labelled `seasonYear`.
    let window: (_ seasonYear: Int, _ calendar: Calendar) -> DateInterval?
}

enum SeasonalChallenges {
    static let all: [SeasonalChallenge] = [blackFriday, twelveDays, january]

    static let blackFriday = SeasonalChallenge(
        id: "black-friday",
        title: "Black Friday No-Buy Weekend",
        description: "Skip the Black Friday and Cyber Monday deals: no non-essential purchases from Friday through Monday.",
        durationDays: 4,
        difficulty: .medium,
        estimatedSavings: 250,
        window: { year, cal in
            guard let friday = blackFridayDate(year: year, calendar: cal) else { return nil }
            return interval(from: cal.date(byAdding: .day, value: -14, to: friday),
                            to: cal.date(byAdding: .day, value: 4, to: friday))
        })

    static let twelveDays = SeasonalChallenge(
        id: "twelve-days",
        title: "12 Days of No-Spend",
        description: "Twelve no-spend days in a row before Christmas. Gifts you already planned are fine; the extras aren't.",
        durationDays: 12,
        difficulty: .medium,
        estimatedSavings: 300,
        window: { year, cal in
            interval(from: cal.date(from: DateComponents(year: year, month: 12, day: 1)),
                     to: cal.date(from: DateComponents(year: year, month: 12, day: 25)))
        })

    static let january = SeasonalChallenge(
        id: "no-spend-january",
        title: "No-Spend January",
        description: "Start the year with 31 days of spending only on essentials like rent, bills, groceries and transport.",
        durationDays: 31,
        difficulty: .hard,
        estimatedSavings: 600,
        window: { year, cal in
            interval(from: cal.date(from: DateComponents(year: year - 1, month: 12, day: 18)),
                     to: cal.date(from: DateComponents(year: year, month: 2, day: 1)))
        })

    /// "Today" for seasonal windows. Debug builds accept `-SeasonalDate YYYY-MM-DD` for QA and artwork.
    static var now: Date {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-SeasonalDate"), i + 1 < args.count {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: args[i + 1]) { return d.addingTimeInterval(12 * 3600) }
        }
        #endif
        return Date()
    }

    static func challenge(forKey key: String) -> SeasonalChallenge? { all.first { $0.id == key } }
    static func challenge(forTitle title: String) -> SeasonalChallenge? { all.first { $0.title == title } }

    /// The offer window containing `date`, if the challenge is currently offered.
    static func window(of challenge: SeasonalChallenge, containing date: Date,
                       calendar: Calendar = .current) -> DateInterval? {
        let year = calendar.component(.year, from: date)
        for seasonYear in [year - 1, year, year + 1] {
            if let w = challenge.window(seasonYear, calendar), w.start <= date, date < w.end { return w }
        }
        return nil
    }

    /// The day after the fourth Thursday of November.
    static func blackFridayDate(year: Int, calendar: Calendar) -> Date? {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        guard let thanksgiving = gregorian.date(from: DateComponents(year: year, month: 11, weekday: 5,
                                                                      weekdayOrdinal: 4)) else { return nil }
        return gregorian.date(byAdding: .day, value: 1, to: gregorian.startOfDay(for: thanksgiving))
    }

    private static func interval(from start: Date?, to end: Date?) -> DateInterval? {
        guard let start, let end, start < end else { return nil }
        return DateInterval(start: start, end: end)
    }
}

/// Holds a deep link until the main UI is on screen (it may arrive during onboarding or the paywall).
@MainActor
@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    /// Challenge library to open; an empty string opens it without highlighting a challenge.
    var pendingChallengeKey: String?

    private init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-DeepLink"), i + 1 < args.count, let url = URL(string: args[i + 1]) {
            handle(url)
        }
        #endif
    }

    /// `spendzero://challenge/<id>` or `spendzero://challenges`.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "spendzero" else { return false }
        switch url.host?.lowercased() {
        case "challenge":
            pendingChallengeKey = url.pathComponents.dropFirst().first ?? ""
        case "challenges":
            pendingChallengeKey = ""
        default:
            return false
        }
        return true
    }
}
