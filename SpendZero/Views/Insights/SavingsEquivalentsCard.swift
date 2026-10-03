import SwiftUI

/// Turns money kept into things you can picture: "enough for 142 coffees". Never claims the money
/// was spent: it's what the savings *could* cover. The user picks three items and can set a goal
/// of their own with its price (UserDefaults only).
struct SavingsEquivalentsCard: View {
    let totalSaved: Double

    @AppStorage("savingsEquivalents.items") private var itemsRaw = "coffee,streaming,trip"
    @AppStorage("savingsEquivalents.prices") private var pricesRaw = ""
    @AppStorage("savingsEquivalents.goalName") private var goalName = ""
    @AppStorage("savingsEquivalents.goalPrice") private var goalPrice = 0.0
    @AppStorage("savingsEquivalents.goalIcon") private var goalIcon = "star.fill"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var editing = false

    private var selected: [EquivalentItem] {
        let ids = itemsRaw.split(separator: ",").map(String.init)
        let items = ids.compactMap { id in EquivalentItem.all.first { $0.id == id } }
        return items.isEmpty ? Array(EquivalentItem.all.prefix(3)) : Array(items.prefix(3))
    }

    private var prices: [String: Double] { EquivalentItem.decodePrices(pricesRaw) }
    private func price(of item: EquivalentItem) -> Double { prices[item.id] ?? item.defaultPrice }

    var body: some View {
        InsightCard(Text("What your savings could buy"),
                    subtitle: Text("\(totalSaved.currencyFormatted) kept is enough for…")) {
            Button {
                CoinHaptics.tick()
                editing = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.app(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppTheme.surfaceElevated))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Choose items"))
        } content: {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(Array(selected.enumerated()), id: \.element.id) { index, item in
                        EquivalentTile(item: item, price: price(of: item), total: shown ? totalSaved : 0)
                            .scaleEffect(shown || reduceMotion ? 1 : 0.9)
                            .opacity(shown || reduceMotion ? 1 : 0)
                            .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3).delay(0.08 * Double(index)),
                                       value: shown)
                    }
                }
                goalRow
            }
        }
        .onAppear {
            guard !shown else { return }
            if reduceMotion { shown = true; return }
            withAnimation(.snappy(duration: 0.9).delay(0.2)) { shown = true }
        }
        .sheet(isPresented: $editing) {
            EquivalentsEditor(itemsRaw: $itemsRaw, pricesRaw: $pricesRaw, goalName: $goalName,
                              goalPrice: $goalPrice, goalIcon: $goalIcon)
        }
    }

    // MARK: Goal

    @ViewBuilder
    private var goalRow: some View {
        let hasGoal = !goalName.trimmingCharacters(in: .whitespaces).isEmpty && goalPrice > 0
        Button {
            CoinHaptics.tick()
            editing = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: hasGoal ? goalIcon : "plus")
                    .font(.app(size: 17, weight: .bold))
                    .foregroundStyle(hasGoal ? Color(hex: "3D2600") : AppTheme.accentGold)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(hasGoal
                                      ? AnyShapeStyle(RadialGradient(colors: MintPalette.levels[1], center: UnitPoint(x: 0.32, y: 0.28),
                                                                     startRadius: 0, endRadius: 32))
                                      : AnyShapeStyle(AppTheme.accentGold.opacity(0.12)))
                    )
                    .goldSheen(hasGoal ? 1 : 0)
                if hasGoal {
                    goalProgress
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add a goal of your own")
                            .font(.app(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("A bike, a trip, a new laptop: set its price and watch your savings close in.")
                            .font(.app(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.surfaceElevated.opacity(0.6)))
        }
        .buttonStyle(.plain)
    }

    private var goalProgress: some View {
        let fraction = goalPrice > 0 ? totalSaved / goalPrice : 0
        let shownFraction = shown ? min(1, fraction) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(goalName)
                    .font(.app(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(goalPrice.currencyFormatted)
                    .font(.app(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            GeometryReader { geo in
                Capsule().fill(AppTheme.textTertiary.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule().fill(AppTheme.goldGradient)
                            .frame(width: max(6, geo.size.width * shownFraction))
                    }
            }
            .frame(height: 7)
            Group {
                if fraction >= 2 {
                    Text("Enough for it \(Int(fraction))× over")
                } else if fraction >= 1 {
                    Text("You've kept enough for it")
                } else {
                    Text("\(Int(fraction * 100))% there · \((goalPrice - totalSaved).currencyFormatted) to go")
                }
            }
            .font(.app(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(fraction >= 1 ? AppTheme.accentGold : AppTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tile

private struct EquivalentTile: View {
    let item: EquivalentItem
    let price: Double
    let total: Double

    private var exact: Double { price > 0 ? total / price : 0 }
    private var count: Int { Int(exact.rounded(.down)) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [item.tint.opacity(0.55), item.tint.opacity(0.08)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 34))
                Circle().strokeBorder(item.tint.opacity(0.45), lineWidth: 1)
                Image(systemName: item.icon)
                    .font(.app(size: 21, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)

            if exact >= 1 || total == 0 {
                Text(count, format: .number)
                    .font(.app(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(count == 1 ? item.singular : item.plural)
                    .font(.app(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            } else {
                Text("\(Int(exact * 100))%")
                    .font(.app(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: exact))
                Text(item.partial)
                    .font(.app(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            Text("at \(price.currencyFormatted) each")
                .font(.app(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .top)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.surfaceElevated.opacity(0.6)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(exact >= 1
                            ? Text("Enough for \(count) \(count == 1 ? item.singular : item.plural)")
                            : Text("\(Int(exact * 100))% \(item.partial)"))
    }
}

// MARK: - Items

struct EquivalentItem: Identifiable, Equatable {
    let id: String
    let icon: String
    let usdPrice: Double
    let singular: String
    let plural: String
    let partial: String
    let tint: Color

    static let all: [EquivalentItem] = [
        .init(id: "coffee", icon: "cup.and.saucer.fill", usdPrice: 5,
              singular: String(localized: "coffee"), plural: String(localized: "coffees"),
              partial: String(localized: "of a coffee"), tint: Color(hex: "C27C3A")),
        .init(id: "streaming", icon: "play.tv.fill", usdPrice: 15,
              singular: String(localized: "month of streaming"), plural: String(localized: "months of streaming"),
              partial: String(localized: "of a month of streaming"), tint: Color(hex: "9C5BFF")),
        .init(id: "trip", icon: "suitcase.rolling.fill", usdPrice: 450,
              singular: String(localized: "weekend away"), plural: String(localized: "weekends away"),
              partial: String(localized: "of a weekend away"), tint: Color(hex: "00BFA5")),
        .init(id: "flight", icon: "airplane", usdPrice: 600,
              singular: String(localized: "return flight"), plural: String(localized: "return flights"),
              partial: String(localized: "of a return flight"), tint: Color(hex: "448AFF")),
        .init(id: "dinner", icon: "fork.knife", usdPrice: 45,
              singular: String(localized: "dinner out"), plural: String(localized: "dinners out"),
              partial: String(localized: "of a dinner out"), tint: Color(hex: "FF6B6B")),
        .init(id: "concert", icon: "music.mic", usdPrice: 90,
              singular: String(localized: "concert ticket"), plural: String(localized: "concert tickets"),
              partial: String(localized: "of a concert ticket"), tint: Color(hex: "E91E63")),
        .init(id: "groceries", icon: "cart.fill", usdPrice: 120,
              singular: String(localized: "week of groceries"), plural: String(localized: "weeks of groceries"),
              partial: String(localized: "of a week of groceries"), tint: Color(hex: "4CAF50"))
    ]

    /// Rough local-currency default so ¥5 coffees never happen; the user can change any price.
    var defaultPrice: Double {
        let factors: [String: Double] = ["JPY": 150, "KRW": 1300, "INR": 80, "TRY": 35, "MXN": 18, "BRL": 5,
                                         "CNY": 7, "SEK": 10, "NOK": 10, "DKK": 7, "PLN": 4, "ZAR": 18, "HKD": 8]
        let code = Locale.current.currency?.identifier ?? "USD"
        let raw = usdPrice * (factors[code] ?? 1)
        let magnitude = pow(10, max(0, floor(log10(raw)) - 1))
        return (raw / magnitude).rounded() * magnitude
    }

    static func decodePrices(_ raw: String) -> [String: Double] {
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return dict
    }

    static func encodePrices(_ prices: [String: Double]) -> String {
        guard let data = try? JSONEncoder().encode(prices) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Editor

private struct EquivalentsEditor: View {
    @Binding var itemsRaw: String
    @Binding var pricesRaw: String
    @Binding var goalName: String
    @Binding var goalPrice: Double
    @Binding var goalIcon: String
    @Environment(\.dismiss) private var dismiss

    @State private var chosen: [String] = []
    @State private var priceText: [String: String] = [:]
    @State private var goalPriceText = ""

    private static let goalIcons = ["star.fill", "bicycle", "laptopcomputer", "gamecontroller.fill", "camera.fill",
                                    "gift.fill", "house.fill", "car.fill", "graduationcap.fill", "pawprint.fill",
                                    "beach.umbrella.fill", "guitars.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(EquivalentItem.all) { item in
                        HStack(spacing: 12) {
                            Button {
                                toggle(item.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: chosen.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(chosen.contains(item.id) ? AppTheme.primaryGreen : AppTheme.textTertiary)
                                        .font(.app(size: 20))
                                    Image(systemName: item.icon)
                                        .foregroundStyle(item.tint)
                                        .frame(width: 24)
                                    Text(item.plural.capitalized(with: .current))
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(chosen.contains(item.id) ? .isSelected : [])
                            Spacer()
                            TextField(item.defaultPrice.currencyFormatted, text: binding(for: item.id))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .accessibilityLabel(Text("Price"))
                        }
                    }
                } header: {
                    Text("Show up to three")
                } footer: {
                    Text("Prices are your own estimates. Tap a price to change it.")
                }

                Section {
                    TextField(String(localized: "What are you saving for?"), text: $goalName)
                    TextField(String(localized: "Price"), text: $goalPriceText)
                        .keyboardType(.decimalPad)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.goalIcons, id: \.self) { icon in
                                Button {
                                    CoinHaptics.tick()
                                    goalIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.app(size: 17, weight: .semibold))
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(goalIcon == icon ? Color(hex: "3D2600") : AppTheme.textSecondary)
                                        .background(Circle().fill(goalIcon == icon ? AppTheme.accentGold : AppTheme.surfaceElevated))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(goalIcon == icon ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if !goalName.isEmpty {
                        Button(role: .destructive) {
                            goalName = ""
                            goalPrice = 0
                            goalPriceText = ""
                        } label: {
                            Text("Remove goal")
                        }
                    }
                } header: {
                    Text("Your goal")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(Text("What your savings could buy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("Done") }
                }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(get: { priceText[id] ?? "" }, set: { priceText[id] = $0 })
    }

    private func toggle(_ id: String) {
        CoinHaptics.tick()
        if let i = chosen.firstIndex(of: id) {
            if chosen.count > 1 { chosen.remove(at: i) }
        } else {
            if chosen.count >= 3 { chosen.removeFirst() }
            chosen.append(id)
        }
    }

    private func load() {
        chosen = itemsRaw.split(separator: ",").map(String.init)
        let prices = EquivalentItem.decodePrices(pricesRaw)
        for (id, value) in prices { priceText[id] = String(format: "%g", value) }
        goalPriceText = goalPrice > 0 ? String(format: "%g", goalPrice) : ""
    }

    private func save() {
        itemsRaw = chosen.joined(separator: ",")
        var prices: [String: Double] = [:]
        for (id, text) in priceText { if let v = Double.parseAmount(text) { prices[id] = v } }
        pricesRaw = EquivalentItem.encodePrices(prices)
        if let v = Double.parseAmount(goalPriceText) { goalPrice = v } else if goalPriceText.isEmpty { goalPrice = 0 }
        CoinHaptics.tick()
        dismiss()
    }
}
