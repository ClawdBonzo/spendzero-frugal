#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only: extends `DemoSeeder` with a believable year of history (Jan 1 → 30 days ago) so
/// the Mint Calendar and Progress charts have a full year to show. Deterministic (seeded RNG),
/// so screenshots are identical run to run. Called from `DemoSeeder.seed(into:)`.
enum InsightsDemoSeeder {
    @MainActor
    static func seedHistory(into context: ModelContext, profile: UserProfile) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yearStart = cal.date(from: cal.dateComponents([.year], from: today)) ?? today
        // At least ~7 months of history even early in the year.
        let start = min(yearStart, cal.date(byAdding: .day, value: -210, to: today) ?? yearStart)
        let firstOffset = cal.dateComponents([.day], from: start, to: today).day ?? 0
        guard firstOffset >= 30 else { return }

        var rng = SeededGenerator(seed: 2026)
        func roll() -> Double { Double.random(in: 0..<1, using: &rng) }

        // A 41-day run ending ~2 months ago matches the profile's longest streak.
        let runEnd = 62, runStart = runEnd + 40
        let wants: [SpendCategory] = [.coffee, .delivery, .shopping, .eatingOut, .entertainment, .clothing, .snacks, .beauty]

        for offset in 30...firstOffset {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let progress = 1 - Double(offset) / Double(max(firstOffset, 1))   // 0 = oldest, 1 = recent
            let odds = 0.38 + 0.5 * progress
            let sealed: Bool
            if (runEnd...runStart).contains(offset) { sealed = true }
            else if offset == runEnd - 1 || offset == runStart + 1 { sealed = false }
            else { sealed = roll() < odds }

            let noon = cal.date(byAdding: .hour, value: 12, to: day) ?? day
            let record = DailyRecord(date: day, isNoSpendDay: sealed)
            if sealed {
                // Weekends keep more (skipped brunch, no shopping trip).
                let weekend = cal.isDateInWeekend(day)
                let kept = (Double(Int.random(in: 18...46, using: &rng)) + (weekend ? 18 : 0)).rounded()
                record.totalSaved = kept
                record.impulsesResisted = roll() < 0.3 ? 1 : 0
                record.mood = roll() < 0.5 ? .great : .good
                context.insert(SavingsEntry(amount: kept, date: noon, source: .noSpendDay))
                if roll() < 0.22 {
                    context.insert(SpendingLog(amount: Double(Int.random(in: 24...86, using: &rng)), category: .groceries,
                                               date: noon))
                }
            } else if roll() < 0.85 {
                // Logged a spend day.
                let amount = Double(Int.random(in: 9...72, using: &rng))
                record.totalSpent = amount
                record.impulsesGivenIn = 1
                record.mood = roll() < 0.5 ? .tough : .neutral
                let category = wants[Int.random(in: 0..<wants.count, using: &rng)]
                context.insert(SpendingLog(amount: amount, category: category, date: noon, wasImpulse: roll() < 0.6))
            } else {
                continue   // not logged at all: still a missed day on the calendar
            }
            context.insert(record)
        }

        // Urges resisted through the year, across categories (feeds the icon ring).
        let urges: [(String, Double, SpendCategory)] = [
            ("Oat latte", 6, .coffee), ("Cold brew", 5, .coffee), ("Pastry and coffee", 9, .coffee),
            ("Coffee beans subscription", 22, .coffee), ("Friday takeout", 38, .delivery), ("Late sushi", 44, .delivery),
            ("Pizza night", 29, .delivery), ("Flash-sale jacket", 120, .clothing), ("Running shorts", 45, .clothing),
            ("Wireless earbuds", 179, .electronics), ("Smartwatch band", 39, .electronics), ("Home decor haul", 85, .shopping),
            ("Kitchen gadget", 34, .shopping), ("Candle bundle", 42, .shopping), ("Skincare set", 58, .beauty),
            ("Streaming add-on", 12, .subscriptions), ("Festival ticket", 140, .entertainment), ("Brunch out", 46, .eatingOut),
            ("Candy run", 9, .snacks), ("Wine club box", 65, .alcohol)
        ]
        for (i, urge) in urges.enumerated() {
            let offset = 34 + i * max(1, (firstOffset - 40) / urges.count)
            guard let day = cal.date(byAdding: .day, value: -offset, to: today),
                  let when = cal.date(byAdding: .hour, value: 15, to: day) else { continue }
            let log = ImpulseLog(item: urge.0, estimatedCost: urge.1, category: urge.2, wasResisted: true,
                                 triggerNote: "Saw it online", copingStrategy: "Waited 24 hours")
            log.date = when
            context.insert(log)
            context.insert(SavingsEntry(amount: urge.1, date: when, source: .impulseResisted))
        }

        profile.createdAt = start
    }

    /// Keep the profile's running total honest with the seeded ledger.
    @MainActor
    static func reconcileTotal(into context: ModelContext, profile: UserProfile) {
        let all = (try? context.fetch(FetchDescriptor<SavingsEntry>())) ?? []
        profile.totalSaved = all.reduce(0) { $0 + $1.amount }
    }
}
#endif
