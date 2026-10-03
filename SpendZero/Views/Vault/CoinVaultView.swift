import SwiftUI
import SwiftData
import SpriteKit

/// The Coin Vault: every sealed no-spend day is a gold coin in a glass jar. Coins settle with
/// real physics, follow device tilt, and the newest one drops in the first time you see it.
struct CoinVaultView: View {
    let profile: UserProfile?

    @Query(filter: #Predicate<DailyRecord> { $0.isNoSpendDay }, sort: \DailyRecord.date)
    private var sealedRecords: [DailyRecord]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var holder = SceneHolder()
    @State private var inViewport = false
    @State private var onScreen = false
    /// SpriteKit shows an opaque grey placeholder until its first frame; never pause before that.
    @State private var primed = false
    /// Coins shown in the stat tiles; lags the data while a coin is still falling.
    @State private var shownCount: Int?
    @State private var pendingDrop = false
    @State private var sealingJar = false
    @State private var glowPulse = false
    @State private var selection: Selection?
    @State private var barArrived = false

    private static let seenKey = "vault.lastSeenCoinCount"

    private struct Selection: Equatable {
        let coin: VaultCoin
        let point: CGPoint
    }

    @MainActor
    final class SceneHolder {
        lazy var scene = VaultScene(size: CGSize(width: 340, height: 420))
    }

    // MARK: Data

    /// Every minted coin, oldest first. Today only counts once it has actually been sealed (a record
    /// for today exists as soon as anything is logged).
    private var allCoins: [VaultCoin] {
        let cal = Calendar.current
        let sealedToday = profile?.hasLoggedToday() ?? false
        var seen = Set<Date>()
        var result: [VaultCoin] = []
        for record in sealedRecords {
            let day = cal.startOfDay(for: record.date)
            if cal.isDateInToday(day) && !sealedToday { continue }
            if day > Date() { continue }
            guard seen.insert(day).inserted else { continue }
            result.append(VaultCoin(id: record.id, date: day, day: result.count + 1, amount: record.totalSaved))
        }
        #if DEBUG
        if let extra = Self.debugExtraCoins, extra > 0 {
            let fake = (0..<extra).map { i in
                VaultCoin(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i)) ?? UUID(),
                          date: cal.date(byAdding: .day, value: -400 + i, to: Date()) ?? Date(), day: 0, amount: 0)
            }
            return (fake + result).enumerated().map { VaultCoin(id: $1.id, date: $1.date, day: $0 + 1, amount: $1.amount) }
        }
        #endif
        return result
    }

    /// The coins in the current jar. While a full jar is sealing it still holds all of its coins.
    private func jarCoins(_ coins: [VaultCoin], count: Int, sealing: Bool) -> [VaultCoin] {
        let visible = Array(coins.prefix(count))
        let cap = JarGeometry.capacity
        let inJar = visible.count % cap
        if inJar == 0 && !visible.isEmpty && sealing { return Array(visible.suffix(cap)) }
        return Array(visible.suffix(inJar))
    }

    // MARK: Body

    var body: some View {
        let coins = allCoins
        let count = min(shownCount ?? coins.count, coins.count)
        let cap = JarGeometry.capacity
        let inJar = sealingJar ? cap : count % cap
        let fullJars = sealingJar ? max(0, count / cap - 1) : count / cap
        let kept = coins.prefix(count).reduce(0) { $0 + $1.amount }

        VStack(alignment: .leading, spacing: 12) {
            header(fullJars: fullJars)
            jarCard(coins: coins, inJar: inJar, isEmpty: coins.isEmpty)
            HStack(spacing: 10) {
                VaultStatTile(label: "coins minted") {
                    Text("\(count)")
                        .font(.app(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.accentGold)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(count)))
                        .animation(.snappy, value: count)
                }
                VaultStatTile(label: "kept on sealed days") {
                    RollingMoney(value: kept, font: .app(size: 24, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                VaultStatTile(label: "until it's full") {
                    Text("\(cap - inJar)")
                        .font(.app(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(cap - inJar)))
                        .animation(.snappy, value: inJar)
                }
            }
        }
        .onAppear {
            onScreen = true
            TiltMotion.shared.start()
            prepare(coins)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { primed = true }
        }
        .onDisappear {
            onScreen = false
            TiltMotion.shared.stop()
            selection = nil
        }
        .onChange(of: isActive) { _, active in
            if active { reveal(coins) }
        }
        .onChange(of: coins.map(\.id)) { _, _ in
            prepare(coins)
            if isActive { reveal(coins) }
        }
        .onChange(of: reduceMotion) { _, rm in holder.scene.isStatic = rm }
    }

    private var isActive: Bool { inViewport && onScreen && scenePhase == .active }

    private func header(fullJars: Int) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coin Vault")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Every sealed day mints a coin.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 8)
            if fullJars > 0 {
                fullJarsRow(fullJars)
            }
        }
    }

    /// One gold bar per jar that has been filled and sealed.
    private func fullJarsRow(_ n: Int) -> some View {
        HStack(spacing: -6) {
            ForEach(0..<min(n, 5), id: \.self) { i in
                GoldBar(width: 26)
                    .zIndex(Double(-i))
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
            if n > 5 {
                Text(verbatim: "+\(n - 5)")
                    .font(.app(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.accentGold)
                    .padding(.leading, 10)
            }
        }
        .goldSheen(0.7)
        .scaleEffect(barArrived ? 1.18 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(n) full jars"))
    }

    // MARK: Jar card

    private func jarCard(coins: [VaultCoin], inJar: Int, isEmpty: Bool) -> some View {
        let fill = Double(inJar) / Double(JarGeometry.capacity)
        return GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width, height: proxy.size.height)
            let g = JarGeometry(size: size)
            ZStack(alignment: .topLeading) {
                JarGlassBack(geometry: g, fill: fill, pulse: glowPulse)
                SpriteView(scene: holder.scene,
                           isPaused: primed && !isActive,
                           preferredFramesPerSecond: UIScreen.main.maximumFramesPerSecond,
                           options: [.allowsTransparency, .ignoresSiblingOrder])
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)
                JarGlassFront(geometry: g, fill: fill)

                if isEmpty {
                    Text("Seal your first no-spend day to mint a coin.")
                        .font(.app(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(width: g.jarRect.width - 48)
                        .position(x: g.jarRect.midX, y: g.jarRect.midY + 20)
                }

                if let selection {
                    CoinCallout(coin: selection.coin)
                        .fixedSize()
                        .modifier(CalloutPlacement(anchor: selection.point, bounds: size, radius: g.coinRadius))
                        .transition(.scale(scale: 0.5, anchor: selection.point.x < size.width / 2 ? .leading : .trailing)
                            .combined(with: .opacity))
                        .id(selection.coin.id)
                }

                hints
                    .frame(width: size.width)
                    .position(x: size.width / 2, y: size.height - 18)
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in handleTap(location) }
        }
        .frame(height: 440)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.08), .white.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onScrollVisibilityChange(threshold: 0.35) { inViewport = $0 }
        .task(id: selection?.coin.id) {
            guard selection != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.smooth(duration: 0.25)) { selection = nil }
            holder.scene.select(nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Coin Vault"))
        .accessibilityValue(Text("\(inJar) of \(JarGeometry.capacity) coins in this jar"))
    }

    private var hints: some View {
        HStack(spacing: 18) {
            if !reduceMotion {
                Label { Text("Tilt to shake") } icon: { Image(systemName: "iphone.gen3.motion") }
            }
            Label { Text("Tap a coin for its day") } icon: { Image(systemName: "hand.tap") }
        }
        .font(.app(size: 12, weight: .bold))
        .foregroundStyle(Color(hex: "8B97A6"))
        .labelStyle(VaultHintLabelStyle())
    }

    // MARK: Behaviour

    private func handleTap(_ location: CGPoint) {
        if let (coin, point) = holder.scene.coin(atViewPoint: location) {
            CoinHaptics.tick()
            holder.scene.select(coin.id)
            withAnimation(.spring(duration: 0.4, bounce: 0.45)) { selection = Selection(coin: coin, point: point) }
        } else if selection != nil {
            holder.scene.select(nil)
            withAnimation(.smooth(duration: 0.2)) { selection = nil }
        }
    }

    /// Lays the jar out before it is seen, holding back the newest coin if it hasn't been seen yet.
    private func prepare(_ coins: [VaultCoin]) {
        let scene = holder.scene
        scene.isStatic = reduceMotion
        scene.onLanded = { _ in coinLanded() }
        guard !pendingDrop else { return }
        let defaults = UserDefaults.standard
        var last = defaults.object(forKey: Self.seenKey) as? Int
        #if DEBUG
        if Self.debugSimulateSeal, !Self.debugSealConsumed { last = max(0, coins.count - 1) }
        #endif
        if last == nil {
            // First ever look: nothing to celebrate, everything is already in the jar.
            defaults.set(coins.count, forKey: Self.seenKey)
            last = coins.count
        }
        if let last, coins.count > last {
            // Only the newest coin drops in; anything older is already settled.
            pendingDrop = true
            shownCount = coins.count - 1
            sealingJar = coins.count % JarGeometry.capacity == 0
            scene.show(jarCoins(coins, count: coins.count - 1, sealing: false), dropNewest: false)
        } else {
            if let last, coins.count < last { defaults.set(coins.count, forKey: Self.seenKey) }
            shownCount = nil
            scene.show(jarCoins(coins, count: coins.count, sealing: false), dropNewest: false)
        }
    }

    /// The jar has scrolled into view: drop the newest coin if one is waiting.
    private func reveal(_ coins: [VaultCoin]) {
        guard pendingDrop else { return }
        #if DEBUG
        Self.debugSealConsumed = true
        #endif
        UserDefaults.standard.set(coins.count, forKey: Self.seenKey)
        let scene = holder.scene
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 450))
            scene.show(jarCoins(coins, count: coins.count, sealing: sealingJar), dropNewest: true)
        }
    }

    private func coinLanded() {
        pendingDrop = false
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
            shownCount = nil
            glowPulse = true
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.35)) { glowPulse = false }
        #if DEBUG
        if Self.debugSelectNewest, let newest = allCoins.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { select(newest) }
        }
        #endif
        guard sealingJar else { return }
        // The jar is full: it melts into a gold bar that joins the row, and a fresh jar begins.
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.3 : 0.9)) {
            CoinHaptics.levelUp()
            SoundEffects.play(.chime, volume: 0.5)
            holder.scene.meltAll {
                withAnimation(.spring(duration: 0.6, bounce: 0.5)) {
                    sealingJar = false
                    barArrived = true
                }
                withAnimation(.spring(duration: 0.5).delay(0.4)) { barArrived = false }
            }
        }
    }

    #if DEBUG
    private func select(_ coin: VaultCoin) {
        guard let point = holder.scene.viewPosition(of: coin.id) else { return }
        holder.scene.select(coin.id)
        withAnimation(.spring(duration: 0.4, bounce: 0.45)) { selection = Selection(coin: coin, point: point) }
    }

    private static var debugSealConsumed = false
    private static var debugSimulateSeal: Bool { ProcessInfo.processInfo.arguments.contains("-VaultSimulateSeal") }
    private static var debugSelectNewest: Bool { ProcessInfo.processInfo.arguments.contains("-VaultSelectNewest") }
    /// `-VaultExtraCoins N` prepends N placeholder coins (QA for full jars and the gold-bar row).
    private static var debugExtraCoins: Int? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-VaultExtraCoins"), i + 1 < a.count else { return nil }
        return Int(a[i + 1])
    }
    #endif
}

// MARK: - Pieces

private struct VaultHintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
    }
}

private struct VaultStatTile<Value: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var value: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            value
            Text(label)
                .font(.app(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "8B97A6"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.cardBackground))
        .accessibilityElement(children: .combine)
    }
}

/// The springy bubble that names a coin's day.
private struct CoinCallout: View {
    let coin: VaultCoin

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "\(coin.date.formatted(.dateTime.month(.abbreviated).day())) · \(String(localized: "Day \(coin.day)"))")
                .font(.app(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.accentGold)
            Text("\(coin.amount.currencyFormatted) kept")
                .font(.app(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "A9B4C2"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.background.opacity(0.94))
                .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.accentGold.opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Places the callout beside its coin, on whichever side has room, kept inside the card.
private struct CalloutPlacement: ViewModifier {
    let anchor: CGPoint
    let bounds: CGSize
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .alignmentGuide(.leading) { d in
                let gap = radius + 10
                let right = anchor.x < bounds.width / 2
                var x = right ? anchor.x + gap : anchor.x - gap - d.width
                x = min(max(12, x), bounds.width - d.width - 12)
                return -x
            }
            .alignmentGuide(.top) { d in
                let y = min(max(12, anchor.y - d.height / 2 - radius * 0.8), bounds.height - d.height - 44)
                return -y
            }
    }
}
