import Foundation

/// Decides when to ask for an App Store rating. Only ever uses the system prompt (no custom
/// "do you like us?" gate, which App Review rejects), and only right after a genuine win:
/// the 3rd no-spend day, a 7-day streak, reaching Level 5, finishing a challenge, and every
/// 15th no-spend day after the 3rd. Each milestone asks once; at most 3 asks per rolling year,
/// at least 30 days apart. The actual request waits until every celebration is dismissed.
enum ReviewPrompter {
    static let maxPerYear = 3
    static let minGapDays = 30

    private static let asksKey = "review.askDates"
    private static let usedKey = "review.usedMilestones"

    // MARK: Pure rules (unit-tested)

    static func candidateMilestones(totalNoSpendDays n: Int, newStreak: Int?,
                                    levelUp: (previous: Int, new: Int)?, challengeCompleted: Bool) -> [String] {
        var out: [String] = []
        if n == 3 { out.append("nsd-3") }
        if n > 3, (n - 3) % 15 == 0 { out.append("nsd-\(n)") }
        if newStreak == 7 { out.append("streak-7") }
        if let lu = levelUp, lu.previous < 5, lu.new >= 5 { out.append("level-5") }
        if challengeCompleted { out.append("challenge") }
        return out
    }

    static func isEligible(previousAsks: [Date], now: Date, calendar: Calendar = .current) -> Bool {
        guard let yearAgo = calendar.date(byAdding: .day, value: -365, to: now) else { return false }
        let recent = previousAsks.filter { $0 > yearAgo }
        guard recent.count < maxPerYear else { return false }
        if let last = recent.max(),
           let gap = calendar.dateComponents([.day], from: last, to: now).day, gap < minGapDays {
            return false
        }
        return true
    }

    // MARK: Stateful wrappers

    @MainActor
    static func milestone(for outcome: ProgressEngine.Outcome, level: Int) -> String? {
        let used = Set(UserDefaults.standard.stringArray(forKey: usedKey) ?? [])
        return candidateMilestones(totalNoSpendDays: outcome.totalNoSpendDays,
                                   newStreak: outcome.newStreak,
                                   levelUp: outcome.levelUp,
                                   challengeCompleted: outcome.challengeCompleted != nil)
            .first { !used.contains($0) }
    }

    static func canAsk(now: Date = Date()) -> Bool {
        isEligible(previousAsks: askDates(), now: now)
    }

    static func recordAsk(milestone: String, at date: Date = Date()) {
        let d = UserDefaults.standard
        d.set((askDates() + [date]).map(\.timeIntervalSince1970), forKey: asksKey)
        d.set((d.stringArray(forKey: usedKey) ?? []) + [milestone], forKey: usedKey)
    }

    private static func askDates() -> [Date] {
        (UserDefaults.standard.array(forKey: asksKey) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
    }
}

/// Streak goals shown as "next milestone" and used to decide what a day unlocks.
enum StreakMilestone {
    static let days = [3, 7, 14, 30, 60, 100, 180, 365]

    static func next(after streak: Int) -> Int? { days.first { $0 > streak } }
    static func previous(atOrBelow streak: Int) -> Int { days.last { $0 <= streak } ?? 0 }

    /// What reaching `day` awards, in display order.
    static func rewards(for day: Int) -> [String] {
        var out: [String] = []
        switch day {
        case 7: out.append(BadgeType.sevenDayStreak.localizedName)
        case 30: out.append(BadgeType.thirtyDayStreak.localizedName)
        case 100: out.append(BadgeType.hundredDayStreak.localizedName)
        case 365: out.append(BadgeType.oneYearStreak.localizedName)
        default: break
        }
        if day % 7 == 0 { out.append(String(localized: "Streak freeze")) }
        return out
    }
}
