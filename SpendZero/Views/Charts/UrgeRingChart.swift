import SwiftUI
import Charts

/// Urges resisted, by category: a ring of rounded sectors with each category's symbol orbiting
/// its slice. Identity is carried by the symbol and the labelled list, never by colour alone.
struct UrgeRingChart: View {
    let data: [InsightsSeries.CategoryCount]
    let givenIn: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep: Double = 0
    @State private var iconsIn = false

    private var total: Int { data.reduce(0) { $0 + $1.count } }
    private var totalValue: Double { data.reduce(0) { $0 + $1.value } }
    private static let ringSize: CGFloat = 168
    private static let orbit: CGFloat = 112

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ring
                    .frame(width: Self.ringSize, height: Self.ringSize)
                centre
                icons
            }
            .frame(width: Self.orbit * 2 + 34, height: Self.orbit * 2 + 34)
            .frame(maxWidth: .infinity)

            list
        }
        .onAppear {
            guard sweep == 0 else { return }
            if reduceMotion { sweep = 1; iconsIn = true; return }
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) { sweep = 1 }
            withAnimation(.spring(duration: 0.5, bounce: 0.4).delay(0.55)) { iconsIn = true }
        }
    }

    private var ring: some View {
        Chart {
            ForEach(data) { item in
                SectorMark(angle: .value("Urges", Double(item.count) * sweep),
                           innerRadius: .ratio(0.66), angularInset: 2.2)
                    .cornerRadius(5)
                    .foregroundStyle(Color(hex: item.category.color).gradient)
                    .accessibilityLabel(Text(item.category.localizedName))
                    .accessibilityValue(Text("\(item.count) resisted"))
            }
            // The unswept remainder keeps proportions fixed while the ring draws in.
            if sweep < 1 {
                SectorMark(angle: .value("Urges", Double(total) * (1 - sweep)), innerRadius: .ratio(0.66))
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
            }
        }
        .chartLegend(.hidden)
        .background(
            Circle()
                .stroke(AppTheme.textTertiary.opacity(0.12), lineWidth: Self.ringSize * 0.17)
                .padding(Self.ringSize * 0.085)
        )
    }

    private var centre: some View {
        VStack(spacing: 0) {
            Text("\(Int((Double(total) * sweep).rounded()))")
                .font(.app(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(total) * sweep))
            Text("urges resisted")
                .font(.app(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            if totalValue > 0 {
                Text("\(totalValue.currencyFormatted) not spent")
                    .font(.app(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.primaryGreen)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(total) urges resisted, \(totalValue.currencyFormatted) not spent"))
    }

    /// Each category's symbol sits on the orbit at the middle of its slice (slices start at 12 o'clock).
    private var icons: some View {
        let slices = sliceMidpoints
        return ZStack {
            ForEach(Array(slices.enumerated()), id: \.element.item.id) { index, slice in
                let angle = slice.mid * 2 * .pi - .pi / 2
                Image(systemName: slice.item.category.icon)
                    .font(.app(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color(hex: slice.item.category.color).gradient)
                            .shadow(color: Color(hex: slice.item.category.color).opacity(0.6), radius: 6)
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                    .offset(x: cos(angle) * Self.orbit, y: sin(angle) * Self.orbit)
                    .scaleEffect(iconsIn ? 1 : 0.2)
                    .opacity(iconsIn ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.45).delay(Double(index) * 0.05),
                               value: iconsIn)
            }
        }
        .accessibilityHidden(true)
    }

    private var sliceMidpoints: [(item: InsightsSeries.CategoryCount, mid: Double)] {
        guard total > 0 else { return [] }
        var running = 0.0
        return data.compactMap { item in
            let share = Double(item.count) / Double(total)
            defer { running += share }
            // Too thin for a symbol of its own; it is still listed below.
            guard share >= 0.05 else { return nil }
            return (item, running + share / 2)
        }
    }

    private var list: some View {
        let maxCount = data.map(\.count).max() ?? 1
        return VStack(spacing: 9) {
            ForEach(data.prefix(6)) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.category.icon)
                        .font(.app(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: item.category.color))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color(hex: item.category.color).opacity(0.16)))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.category.localizedName)
                                .font(.app(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text("\(item.count)")
                                .font(.app(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                                .monospacedDigit()
                        }
                        GeometryReader { geo in
                            Capsule().fill(AppTheme.textTertiary.opacity(0.15))
                                .overlay(alignment: .leading) {
                                    Capsule().fill(Color(hex: item.category.color))
                                        .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount) * sweep)
                                }
                        }
                        .frame(height: 4)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(item.category.localizedName): \(item.count) resisted"))
            }
            if givenIn > 0 {
                Text("You gave in \(givenIn) times in this period. Every urge you log teaches you your triggers.")
                    .font(.app(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }
}
