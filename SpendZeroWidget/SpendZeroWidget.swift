import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared App Group store

private enum WidgetStore {
    static func entry() -> SavingsWidgetEntry {
        let d = WidgetShared.defaults
        return SavingsWidgetEntry(
            date: Date(),
            totalSaved: d?.double(forKey: WidgetShared.Key.totalSaved) ?? 0,
            currentStreak: d?.integer(forKey: WidgetShared.Key.currentStreak) ?? 0,
            isNoSpendDay: d?.object(forKey: WidgetShared.Key.isNoSpendDay) as? Bool ?? true,
            // Day-stamped seal (from the Seal intent / app refresh) covers the gap before the
            // app's snapshot lands; the snapshot flag stays the primary source.
            loggedToday: (d?.bool(forKey: WidgetShared.Key.loggedToday) ?? false) || SealStatus.isSealed(on: Date())
        )
    }
}

// MARK: - Widget Timeline Provider

struct SavingsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavingsWidgetEntry {
        SavingsWidgetEntry(date: Date(), totalSaved: 847, currentStreak: 12, isNoSpendDay: true, loggedToday: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SavingsWidgetEntry) -> Void) {
        // In a gallery/snapshot context, show aspirational sample data.
        if context.isPreview {
            completion(SavingsWidgetEntry(date: Date(), totalSaved: 847, currentStreak: 12, isNoSpendDay: true, loggedToday: false))
        } else {
            completion(WidgetStore.entry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavingsWidgetEntry>) -> Void) {
        let entry = WidgetStore.entry()
        // Refresh at the next hour and again at midnight (so "Logged ✓" resets); the app
        // also force-reloads on every data change.
        let cal = Calendar.current
        let nextHour = cal.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let resetEntry = SavingsWidgetEntry(date: midnight, totalSaved: entry.totalSaved,
                                            currentStreak: entry.currentStreak, isNoSpendDay: true, loggedToday: false)
        completion(Timeline(entries: [entry, resetEntry], policy: .after(min(nextHour, midnight))))
    }

    typealias Entry = SavingsWidgetEntry
}

struct SavingsWidgetEntry: TimelineEntry {
    let date: Date
    let totalSaved: Double
    let currentStreak: Int
    let isNoSpendDay: Bool
    let loggedToday: Bool
}

// MARK: - Widget Views

struct SavingsWidgetView: View {
    var entry: SavingsWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            Text("🔥 \(entry.currentStreak)-day streak · \(entry.totalSaved.widgetCurrency) saved")
        default:
            smallWidget
        }
    }

    private var statusText: LocalizedStringKey {
        if entry.loggedToday { return "Sealed ✓" }
        return entry.isNoSpendDay ? "Tap coin to seal" : "Spent today"
    }

    private var statusColor: Color {
        if entry.loggedToday { return WidgetPalette.green }
        return entry.isNoSpendDay ? WidgetPalette.gold : WidgetPalette.red
    }

    private var brandHeader: some View {
        HStack(spacing: 6) {
            Image("BrandIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text("SpendZero")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                brandHeader
                Spacer(minLength: 0)
                CoinSealButton(entry: entry, size: 50)
            }

            Spacer(minLength: 0)

            Text(entry.totalSaved.widgetCurrency)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetPalette.green)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(value: entry.totalSaved))

            Text("Total Saved")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text(statusText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor)
                .contentTransition(.opacity)
        }
        .containerBackground(for: .widget) { WidgetPalette.backgroundGradient }
    }

    private var accessoryCircular: some View {
        Button(intent: SealTodayIntent()) {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.loggedToday ? "checkmark.seal.fill" : "flame.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(entry.currentStreak)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: Double(entry.currentStreak)))
                }
                .invalidatableContent()
            }
        }
        .buttonStyle(.plain)
        .disabled(entry.loggedToday || !entry.isNoSpendDay)
        .widgetAccentable()
        .accessibilityLabel(entry.loggedToday ? Text("Today is sealed") : Text("Seal today"))
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.totalSaved.widgetCurrency)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .widgetAccentable()
                Text("\(entry.currentStreak)-day streak")
                    .font(.system(size: 12, weight: .medium))
                    .contentTransition(.numericText(value: Double(entry.currentStreak)))
            }
            Spacer(minLength: 0)
            MarkTodayButton(entry: entry, compact: true)
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                brandHeader

                Spacer(minLength: 0)

                Text(entry.totalSaved.widgetCurrency)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetPalette.green)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: entry.totalSaved))

                Text("Total Saved")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 5) {
                    Image(systemName: entry.loggedToday ? "checkmark.circle.fill"
                          : (entry.isNoSpendDay ? "circle.dashed" : "xmark.circle.fill"))
                    Text(entry.isNoSpendDay ? (entry.loggedToday ? "Today: Sealed" : "Today: On Track") : "Today: Spent")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                CoinSealButton(entry: entry, size: 78)
                Text("Day Streak")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetPalette.gold)
                Text(entry.loggedToday ? "Sealed ✓" : (entry.isNoSpendDay ? "Tap to seal" : "Spent today"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(minWidth: 90)
        }
        .containerBackground(for: .widget) { WidgetPalette.backgroundGradient }
    }
}

// MARK: - One-tap "seal today" button (compact, used on the Lock Screen)

/// The core loop without opening the app. Disabled once today is logged or has spending.
struct MarkTodayButton: View {
    let entry: SavingsWidgetEntry
    let compact: Bool

    private var isEnabled: Bool { !entry.loggedToday && entry.isNoSpendDay }

    var body: some View {
        Button(intent: SealTodayIntent()) {
            if compact {
                Image(systemName: entry.loggedToday ? "checkmark.seal.fill" : "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isEnabled ? WidgetPalette.green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .invalidatableContent()
            } else {
                HStack(spacing: 4) {
                    Image(systemName: entry.loggedToday ? "checkmark.circle.fill" : "checkmark.seal.fill")
                    Text(entry.loggedToday ? "Sealed ✓" : "Seal Today")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isEnabled ? .black : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isEnabled ? WidgetPalette.green : Color.secondary.opacity(0.2))
                .clipShape(Capsule())
                .invalidatableContent()
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(entry.loggedToday ? Text("Today is sealed") : Text("Seal today"))
    }
}

// MARK: - Widget Configuration

struct SpendZeroSavingsWidget: Widget {
    let kind = WidgetShared.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavingsProvider()) { entry in
            SavingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Savings Glance")
        .description("Your savings and streak. Tap the gold coin to seal today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Widget Bundle entry point

@main
struct SpendZeroWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendZeroSavingsWidget()
        SealTodayControl()
        SealTodayLiveActivity()
    }
}

// MARK: - Color(hex:) (widget-target copy; app target has its own in AppTheme)

extension Double {
    /// Locale-aware currency string for the widget (e.g. $847, €847, R$847).
    var widgetCurrency: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "\(Locale.current.currencySymbol ?? "$")\(Int(self))"
    }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r, g, b: UInt64
        switch s.count {
        case 3: (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
