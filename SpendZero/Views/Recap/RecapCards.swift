import SwiftUI

// The five recap cards. Each one stages its own entrance when it appears (the story re-mounts a
// card every time it is shown) and jumps straight to its final frame under Reduce Motion.
// Every card is a single VoiceOver element that reads its whole story in one sentence.

/// Layout shared by every card: room for the progress bars on top and the buttons at the bottom.
private struct CardFrame<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: 0) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment == .leading ? .topLeading : .top)
            .padding(.horizontal, 24)
            .padding(.top, 76)
            .padding(.bottom, 96)
    }
}

/// Runs a staged sequence once; under Reduce Motion only the final step's state matters.
private func pause(_ seconds: Double) async -> Bool {
    try? await Task.sleep(for: .seconds(seconds))
    return !Task.isCancelled
}

// MARK: - 1 · Sealed

struct RecapSealedCard: View {
    let recap: MonthRecap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleIn = false
    @State private var count = 0.0
    @State private var revealed = 0
    @State private var captionIn = false

    var body: some View {
        ZStack {
            RecapBackdrop(warmth: 0.35, glow: [AppTheme.accentGold, AppTheme.primaryGreen, AppTheme.accentGold], glowIntensity: 0.12)
            CardFrame {
                RecapEyebrow(text: String(localized: "\(recap.monthName) recap"))
                    .padding(.bottom, 10)
                Text(String(localized: "Your \(recap.monthName), sealed."))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .blur(radius: titleIn ? 0 : 10)
                    .opacity(titleIn ? 1 : 0)
                    .offset(y: titleIn ? 0 : 14)

                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    CountUpText(value: count) { $0.formatted() }
                        .font(.system(size: 124, weight: .black, design: .rounded))
                        .foregroundStyle(RecapStyle.goldText)
                        .goldSheen()
                        .shadow(color: AppTheme.accentGold.opacity(0.35), radius: 22)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(recap.noSpendDays == 1 ? String(localized: "no-spend\nday") : String(localized: "no-spend\ndays"))
                        .font(.app(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.bottom, 22)
                }
                .opacity(titleIn ? 1 : 0)
                .padding(.top, 2)

                RecapCoinCalendar(recap: recap, spacing: 9, revealed: revealed, animated: !reduceMotion)
                    .goldSheen(0.9)
                    .padding(.top, 6)

                Text(String(localized: "\(recap.noSpendDays) of \(recap.days.count) days kept spend-free"))
                    .font(.app(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(RecapStyle.mutedText)
                    .padding(.top, 18)
                    .opacity(captionIn ? 1 : 0)
                    .offset(y: captionIn ? 0 : 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Your \(recap.monthName), sealed. \(recap.noSpendDays) of \(recap.days.count) days were no-spend days."))
        .task { await play() }
    }

    private func play() async {
        let days = recap.days
        if reduceMotion {
            titleIn = true; count = Double(recap.noSpendDays); revealed = days.count; captionIn = true
            return
        }
        guard await pause(0.15) else { return }
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) { titleIn = true }
        guard await pause(0.35) else { return }
        withAnimation(.easeOut(duration: 1.5)) { count = Double(recap.noSpendDays) }
        guard await pause(0.25) else { return }
        for i in days.indices {
            revealed = i + 1
            if days[i] == .sealed, i % 2 == 0 { CoinHaptics.tick() }
            guard await pause(0.045) else { return }
        }
        CoinHaptics.seal()
        SoundEffects.play(.clink, volume: 0.45)
        withAnimation(.easeOut(duration: 0.45)) { captionIn = true }
    }
}

// MARK: - 2 · Money kept

struct RecapMoneyCard: View {
    let recap: MonthRecap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headIn = false
    @State private var amount = 0.0
    @State private var rowsIn = 0
    @State private var pourStart: Date?

    private var coinCount: Int { min(72, max(22, Int(recap.moneyKept / 12))) }

    var body: some View {
        ZStack(alignment: .bottom) {
            RecapBackdrop(warmth: 0.72, glow: [AppTheme.accentGold, AppTheme.primaryGreen, Color(hex: "FFB300")], glowIntensity: 0.16)

            CoinPour(count: coinCount, start: pourStart, seed: UInt64(RecapScheduler.monthKey(recap.month)))
                .goldSheen()
                .frame(height: 230)
                .padding(.horizontal, 10)
                .padding(.bottom, 92)
                .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.2)))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .top)

            CardFrame {
                RecapEyebrow(text: String(localized: "Money kept"))
                    .padding(.bottom, 10)
                Text(String(localized: "In \(recap.monthName) you kept"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .opacity(headIn ? 1 : 0)
                    .offset(y: headIn ? 0 : 12)

                RollingMoney(value: amount, font: .system(size: 80, weight: .black, design: .rounded), color: AppTheme.primaryGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .shadow(color: AppTheme.primaryGreen.opacity(0.45), radius: 24)
                    .opacity(headIn ? 1 : 0)

                Text(String(localized: "kept, not spent"))
                    .font(.app(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(headIn ? 1 : 0)
                    .padding(.bottom, 22)

                VStack(spacing: 10) {
                    ForEach(Array(recap.keptBySource.prefix(3).enumerated()), id: \.element.id) { i, row in
                        HStack(spacing: 12) {
                            Image(systemName: row.source.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.accentGold)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(AppTheme.accentGold.opacity(0.14)))
                            Text(row.source.localizedName)
                                .font(.app(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 8)
                            Text(row.amount.currencyFormatted)
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.primaryGreen)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.28)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
                        .opacity(rowsIn > i ? 1 : 0)
                        .offset(x: rowsIn > i ? 0 : 30)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .task { await play() }
    }

    private var accessibilityText: String {
        var parts = [String(localized: "In \(recap.monthName) you kept \(recap.moneyKept.currencyFormatted), not spent.")]
        for row in recap.keptBySource.prefix(3) {
            parts.append("\(row.source.localizedName): \(row.amount.currencyFormatted).")
        }
        return parts.joined(separator: " ")
    }

    private func play() async {
        let total = recap.moneyKept
        if reduceMotion {
            headIn = true; amount = total; rowsIn = 3; pourStart = .distantPast
            return
        }
        guard await pause(0.15) else { return }
        withAnimation(.spring(duration: 0.55, bounce: 0.2)) { headIn = true }
        pourStart = Date()
        for f in [0.16, 0.42, 0.71, 0.9, 1.0] {
            guard await pause(0.42) else { return }
            amount = (total * f).rounded()
        }
        SoundEffects.play(.chime, volume: 0.4)
        for i in 1...3 {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { rowsIn = i }
            guard await pause(0.16) else { return }
        }
    }
}

// MARK: - 3 · Best streak

struct RecapStreakCard: View {
    let recap: MonthRecap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit = false
    @State private var shown = 0
    @State private var fill = 0.0
    @State private var textIn = false

    private var rangeText: String? {
        guard let r = recap.bestStreakRange,
              let start = Calendar.current.date(byAdding: .day, value: r.lowerBound, to: recap.month),
              let end = Calendar.current.date(byAdding: .day, value: r.upperBound, to: recap.month) else { return nil }
        if r.count == 1 { return start.formatted(.dateTime.month(.abbreviated).day()) }
        return (start..<end).formatted(.interval.month(.abbreviated).day())
    }

    var body: some View {
        ZStack {
            RecapBackdrop(warmth: 1, glow: [RecapStyle.flameColors[2], AppTheme.accentGold, RecapStyle.flameColors[3]], glowIntensity: 0.14)
            CardFrame(alignment: .center) {
                RecapEyebrow(text: String(localized: "Best streak"))
                ZStack {
                    Sunburst(color: RecapStyle.flameColors[2], rays: 16, period: 22)
                        .frame(width: 520, height: 520)
                        .opacity(lit ? 0.9 : 0)
                    RecapFlame(lit: lit)
                        .frame(width: 170, height: 190)
                }
                .frame(height: 210)
                .padding(.top, 8)

                FlipCounter(value: shown, font: .system(size: 112, weight: .black, design: .rounded), color: .white)
                    .shadow(color: RecapStyle.flameColors[2].opacity(0.55), radius: 20)
                    .padding(.top, -6)

                Text(recap.bestStreak == 1 ? String(localized: "day in a row") : String(localized: "days in a row"))
                    .font(.app(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(textIn ? 1 : 0)

                Group {
                    if let rangeText, recap.bestStreak > 0 {
                        Text(String(localized: "Your longest no-spend run, \(rangeText)"))
                    } else {
                        Text(String(localized: "Every streak starts with one sealed day."))
                    }
                }
                .font(.app(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(RecapStyle.mutedText)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .opacity(textIn ? 1 : 0)

                StreakStrip(recap: recap, fill: fill)
                    .padding(.top, 30)
                    .opacity(textIn ? 1 : 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recap.bestStreak == 1
            ? String(localized: "Best streak: 1 day.")
            : String(localized: "Best streak: \(recap.bestStreak) days in a row."))
        .task { await play() }
    }

    private func play() async {
        let best = recap.bestStreak
        if reduceMotion {
            lit = true; shown = best; fill = 1; textIn = true
            return
        }
        guard await pause(0.2) else { return }
        withAnimation(.spring(duration: 0.7, bounce: 0.35)) { lit = true }
        CoinHaptics.tick()
        guard await pause(0.4) else { return }
        withAnimation(.easeOut(duration: 0.4)) { textIn = true }
        // At most ~14 flips, so long streaks still land in about two seconds.
        let step = max(1, Int((Double(best) / 14).rounded(.up)))
        var v = 0
        while v < best {
            v = min(best, v + step)
            shown = v
            fill = best > 0 ? Double(v) / Double(best) : 1
            SoundEffects.play(.flip, volume: 0.18)
            guard await pause(0.17) else { return }
        }
        fill = 1
        if best > 0 { CoinHaptics.seal() }
    }
}

// MARK: - 4 · Urges beaten

struct RecapUrgesCard: View {
    let recap: MonthRecap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headIn = false
    @State private var count = 0.0
    @State private var badgesIn = 0
    @State private var struck = 0
    @State private var biggestIn = false

    var body: some View {
        ZStack {
            RecapBackdrop(warmth: 0.08, glow: [AppTheme.primaryGreen, Color(hex: "00BFA5"), Color(hex: "1DE9B6")], glowIntensity: 0.16)
            CardFrame {
                RecapEyebrow(text: String(localized: "Urges beaten"))
                    .padding(.bottom, 4)
                CountUpText(value: count) { $0.formatted() }
                    .font(.system(size: 124, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "B9F6CA")], startPoint: .top, endPoint: .bottom))
                    .shadow(color: AppTheme.primaryGreen.opacity(0.35), radius: 22)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(headIn ? 1 : 0)
                Text(recap.urgesBeaten == 1
                     ? String(localized: "time you felt the pull and walked away.")
                     : String(localized: "times you felt the pull and walked away."))
                    .font(.app(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(headIn ? 1 : 0)
                    .offset(y: headIn ? 0 : 10)

                if recap.topCategories.isEmpty {
                    Text(String(localized: "Log the urges you resist next month and watch this number grow."))
                        .font(.app(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(RecapStyle.mutedText)
                        .padding(.top, 18)
                        .opacity(headIn ? 1 : 0)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(recap.topCategories.enumerated()), id: \.element.id) { i, entry in
                            BeatenUrgeBadge(entry: entry, shown: badgesIn > i, struck: struck > i)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 34)
                }

                if let big = recap.biggestUrge {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Biggest walk-away"))
                            .font(.app(size: 12, weight: .heavy, design: .rounded))
                            .tracking(1)
                            .foregroundColor(RecapStyle.eyebrow)
                        HStack(alignment: .firstTextBaseline) {
                            Text(big.item)
                                .font(.app(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 8)
                            Text(big.cost.currencyFormatted)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.primaryGreen)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.3)))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.primaryGreen.opacity(0.3), lineWidth: 1))
                    .padding(.top, 30)
                    .opacity(biggestIn ? 1 : 0)
                    .offset(y: biggestIn ? 0 : 16)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .task { await play() }
    }

    private var accessibilityText: String {
        var s = recap.urgesBeaten == 1
            ? String(localized: "You beat 1 urge to spend.")
            : String(localized: "You beat \(recap.urgesBeaten) urges to spend.")
        if !recap.topCategories.isEmpty {
            s += " " + recap.topCategories.map { "\($0.category.localizedName) \($0.count)" }.formatted(.list(type: .and)) + "."
        }
        if let big = recap.biggestUrge {
            s += " " + String(localized: "Biggest walk-away: \(big.item), \(big.cost.currencyFormatted).")
        }
        return s
    }

    private func play() async {
        let n = recap.topCategories.count
        if reduceMotion {
            headIn = true; count = Double(recap.urgesBeaten); badgesIn = n; struck = n; biggestIn = true
            return
        }
        guard await pause(0.15) else { return }
        withAnimation(.spring(duration: 0.55, bounce: 0.2)) { headIn = true }
        withAnimation(.easeOut(duration: 1.2)) { count = Double(recap.urgesBeaten) }
        guard await pause(0.7) else { return }
        for i in 0..<n {
            withAnimation(.spring(duration: 0.45, bounce: 0.45)) { badgesIn = i + 1 }
            Beat.pop()
            guard await pause(0.14) else { return }
        }
        guard await pause(0.2) else { return }
        for i in 0..<n {
            withAnimation(.easeOut(duration: 0.28)) { struck = i + 1 }
            CoinHaptics.tick()
            guard await pause(0.16) else { return }
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) { biggestIn = true }
    }
}

// MARK: - 5 · Wealth tree

struct RecapTreeCard: View {
    let recap: MonthRecap

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var growth: Double
    @State private var level: Int
    @State private var headIn = false
    @State private var chipIn = false
    @State private var confetti = 0

    init(recap: MonthRecap) {
        self.recap = recap
        _growth = State(initialValue: MonthRecap.treeGrowth(level: recap.levelStart))
        _level = State(initialValue: recap.levelStart)
    }

    private var headline: String {
        switch recap.levelsGained {
        case 0: return String(localized: "Your tree held strong.")
        case 1: return String(localized: "Your tree grew 1 level.")
        default: return String(localized: "Your tree grew \(recap.levelsGained) levels.")
        }
    }

    var body: some View {
        ZStack {
            RecapBackdrop(warmth: 0.45, glow: [AppTheme.primaryGreen, AppTheme.accentGold, Color(hex: "00BFA5")], glowIntensity: 0.14)
            CardFrame(alignment: .center) {
                RecapEyebrow(text: String(localized: "Your wealth tree"))
                Text(headline)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 10)
                    .opacity(headIn ? 1 : 0)
                    .offset(y: headIn ? 0 : 12)

                GrowingWealthTree(growth: growth, seed: recap.treeSeed, coins: min(18, Int(recap.moneyKept / 60)))
                    .frame(height: 330)
                    .mask(RadialGradient(colors: [.black, .black, .clear], center: .center, startRadius: 60, endRadius: 210))
                    .padding(.top, 4)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(localized: "Level"))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(RecapStyle.goldText)
                    FlipCounter(value: level, font: .system(size: 56, weight: .black, design: .rounded), color: AppTheme.accentGold)
                }
                .goldSheen()
                .shadow(color: AppTheme.accentGold.opacity(0.35), radius: 16)

                Text((LevelRank(rawValue: recap.levelEnd) ?? .wealthKing).title)
                    .font(.app(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(RecapStyle.mutedText)

                if recap.levelsGained > 0 {
                    Label(String(localized: "+\(recap.levelsGained) in \(recap.monthName)"), systemImage: "arrow.up.circle.fill")
                        .font(.app(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.primaryGreen)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AppTheme.primaryGreen.opacity(0.14)))
                        .overlay(Capsule().stroke(AppTheme.primaryGreen.opacity(0.4), lineWidth: 1))
                        .padding(.top, 10)
                        .scaleEffect(chipIn ? 1 : 0.6)
                        .opacity(chipIn ? 1 : 0)
                }
            }
            CashConfettiBurst(trigger: confetti, origin: UnitPoint(x: 0.5, y: 0.42), count: 80)
                .ignoresSafeArea()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(headline) " + String(localized: "Level \(recap.levelEnd), \((LevelRank(rawValue: recap.levelEnd) ?? .wealthKing).title)."))
        .task { await play() }
    }

    private func play() async {
        let end = MonthRecap.treeGrowth(level: recap.levelEnd)
        if reduceMotion {
            headIn = true; growth = end; level = recap.levelEnd; chipIn = true
            return
        }
        guard await pause(0.15) else { return }
        withAnimation(.spring(duration: 0.55, bounce: 0.2)) { headIn = true }
        guard await pause(0.25) else { return }
        withAnimation(.easeInOut(duration: 2.2)) { growth = end }
        let steps = recap.levelEnd - recap.levelStart
        if steps > 0 {
            let gap = min(0.7, 2.0 / Double(steps))
            for l in (recap.levelStart + 1)...recap.levelEnd {
                guard await pause(gap) else { return }
                level = l
                CoinHaptics.levelUp()
            }
            SoundEffects.play(.levelUp, volume: 0.5)
            confetti += 1
        } else {
            guard await pause(1.6) else { return }
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) { chipIn = true }
    }
}
