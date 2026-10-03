import SwiftUI
import SwiftData

/// Visual money tree that grows through level progression, living in the user's real time of day
/// and season. Plays a falling leaf for spending logged since the last visit and a coin pop for a
/// sealed day (detected here from the store, or queued by the app via `WealthTreeEvents`).
struct MoneyTreeView: View {
    let gameProfile: GameProfile
    var streak: Int = 0
    var totalSaved: Double = 0
    /// True once the user has had a streak and let it lapse — the tree wilts until they return.
    var thirsty: Bool = false

    /// 0…1, continuous across all 25 levels so the tree grows a little with every level.
    private var growth: Double {
        let lvl = Double(gameProfile.currentLevel - 1) + gameProfile.progressToNextLevel
        return min(1, max(0.1, lvl / 24))
    }
    private var vitality: Double { thirsty ? 0.3 : min(1, 0.62 + Double(streak) / 25) }
    private var coins: Int { min(18, Int(totalSaved / 50)) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Read-only: the newest spending logs and savings, to notice what happened since the last visit.
    @Query(MoneyTreeView.spendingDescriptor) private var recentSpending: [SpendingLog]
    @Query(MoneyTreeView.savingsDescriptor) private var recentSavings: [SavingsEntry]
    @AppStorage("wealthTreeLastSeen") private var lastSeen: Double = 0
    @State private var treeEvents = WealthTreeEvents.shared
    @State private var events: [WealthTreeEvent] = []
    @State private var nextEventID = 1
    @State private var visible = false

    static var spendingDescriptor: FetchDescriptor<SpendingLog> {
        var d = FetchDescriptor<SpendingLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        d.fetchLimit = 3
        return d
    }
    static var savingsDescriptor: FetchDescriptor<SavingsEntry> {
        var d = FetchDescriptor<SavingsEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        d.fetchLimit = 8
        return d
    }

    var treeStage: Int {
        switch gameProfile.currentLevel {
        case ...5:  return 1   // Seedling
        case ...10: return 2   // Sprout
        case ...15: return 3   // Young Tree
        case ...20: return 4   // Tall Tree
        default:    return 5   // Full Palm
        }
    }

    var stageIcon: String {
        switch treeStage {
        case 1: return "leaf.fill"
        case 2: return "leaf.circle.fill"
        case 3: return "tree.fill"
        case 4: return "tree.fill"
        default: return "crown.fill"
        }
    }

    var stageTitle: String {
        switch treeStage {
        case 1: return String(localized: "Seedling")
        case 2: return String(localized: "Sprout")
        case 3: return String(localized: "Young Tree")
        case 4: return String(localized: "Tall Tree")
        default: return String(localized: "Full Palm")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("Your Wealth Tree")
                    .font(AppTheme.titleFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Growing with your financial wisdom")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
            }

            WealthTreeCanvas(seed: gameProfile.id.seed64, growth: growth, vitality: vitality, coins: coins,
                             streak: streak, events: events)
                .frame(height: 270)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .fill(AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel("Wealth tree at stage \(treeStage): \(stageTitle)")

            // Vitality: the tree reflects the streak, so a lapse is visible (and fixable).
            HStack(spacing: 8) {
                Image(systemName: thirsty ? "drop.triangle.fill" : (streak > 0 ? "flame.fill" : "leaf.fill"))
                Text(thirsty ? String(localized: "Your tree is thirsty — log a no-spend day to revive it")
                     : streak > 0 ? String(localized: "Thriving · \(streak)-day streak")
                     : String(localized: "Freshly planted — every no-spend day helps it grow"))
                    .lineLimit(2)
                Spacer(minLength: 0)
                if coins > 0 {
                    Label("\(coins)", systemImage: "circle.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundColor(AppTheme.accentGold)
                        .accessibilityLabel(String(localized: "\(coins) gold coins"))
                }
            }
            .font(.app(size: 13, weight: .semibold))
            .foregroundColor(thirsty ? AppTheme.warning : AppTheme.primaryGreen)
            .accessibilityValue("Level \(gameProfile.currentLevel)")

            // Stage info
            VStack(spacing: 8) {
                HStack {
                    Text("Current Stage")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: stageIcon)
                            .font(.app(size: 16, weight: .semibold))
                        Text(stageTitle)
                            .font(AppTheme.headlineFont)
                    }
                    .foregroundColor(AppTheme.accentGold)
                }

                if treeStage < 5 {
                    let nextStageLevel = treeStage * 5 + 1
                    VStack(spacing: 6) {
                        HStack {
                            Text("Level \(nextStageLevel) for next stage")
                                .font(AppTheme.smallFont)
                                .foregroundColor(AppTheme.textTertiary)
                            Spacer()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.cardBackgroundLight)
                                    .frame(height: 8)
                                let progress = min(1.0, Double(gameProfile.currentLevel) / Double(nextStageLevel))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [AppTheme.primaryGreen, AppTheme.accentGold],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * progress, height: 8)
                                    .animation(reduceMotion ? nil : .spring(response: 0.6), value: gameProfile.currentLevel)
                            }
                        }
                        .frame(height: 8)
                    }
                } else {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(AppTheme.accentGold)
                        Text("Wealth King — Ultimate status achieved!")
                            .font(AppTheme.smallFont)
                            .foregroundColor(AppTheme.accentGold)
                    }
                }
            }
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
        }
        .padding(AppTheme.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(AppTheme.background)
        )
        .onAppear {
            visible = true
            collectEvents()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-TreeEvents") { schedule(leafFalls: 1, coinPops: 1) }
            #endif
        }
        .onDisappear {
            visible = false
            lastSeen = Date().timeIntervalSinceReferenceDate
        }
        .onChange(of: recentSpending.first?.date) { if visible { collectEvents() } }
        .onChange(of: latestSeal) { if visible { collectEvents() } }
        .onChange(of: treeEvents.pendingLeafFalls + treeEvents.pendingCoinPops) { if visible { collectEvents() } }
    }

    private var latestSeal: Date? { recentSavings.first { $0.source == .noSpendDay }?.date }

    /// Turns what happened since the last visit (plus anything the app queued) into tree moments.
    private func collectEvents() {
        var leaves = 0, coins = 0
        if lastSeen > 0 {
            let since = Date(timeIntervalSinceReferenceDate: lastSeen)
            leaves = recentSpending.filter { $0.date > since }.count
            if let seal = latestSeal, seal > since { coins = 1 }
        }
        let queued = treeEvents.drain()
        lastSeen = Date().timeIntervalSinceReferenceDate
        schedule(leafFalls: max(leaves, queued.leafFalls), coinPops: max(coins, queued.coinPops))
    }

    private func schedule(leafFalls: Int, coinPops: Int) {
        guard leafFalls + coinPops > 0 else { return }
        // Give the card a beat to settle on screen before anything moves.
        let now = Date().timeIntervalSinceReferenceDate
        let leadIn = 0.9
        for k in 0..<min(3, leafFalls) {
            events.append(WealthTreeEvent(id: nextEventID, kind: .leafFall, start: now + leadIn + Double(k) * 1.4))
            nextEventID += 1
        }
        if coinPops > 0 {
            let delay = leadIn + (leafFalls > 0 ? 0.6 : 0)
            events.append(WealthTreeEvent(id: nextEventID, kind: .coinPop, start: now + delay))
            nextEventID += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard visible else { return }
                CoinHaptics.tick()
                SoundEffects.play(.clink, volume: 0.35)
            }
        }
        // Keep what's still playing, plus the newest finished coin pop (it keeps a first coin shown).
        let horizon = now - 10
        var keptPop = false
        events = Array(events.reversed().filter { ev in
            if ev.start + ev.duration > horizon { return true }
            if ev.kind == .coinPop, !keptPop { keptPop = true; return true }
            return false
        }.reversed())
    }
}

#Preview {
    let profile = GameProfile()
    profile.currentLevel = 15
    return MoneyTreeView(gameProfile: profile)
        .background(AppTheme.background)
}
