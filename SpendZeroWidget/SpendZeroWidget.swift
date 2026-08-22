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
            loggedToday: d?.bool(forKey: WidgetShared.Key.loggedToday) ?? false
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

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("BrandIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text("SpendZero")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(entry.totalSaved.widgetCurrency)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "00E676"))

            Text("Total Saved")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "FFD740"))
                Text("\(entry.currentStreak) day streak")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
                MarkTodayButton(entry: entry, compact: true)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var accessoryCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.loggedToday ? "checkmark.seal.fill" : "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("\(entry.currentStreak)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .widgetAccentable()
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.totalSaved.widgetCurrency)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .widgetAccentable()
                Text("\(entry.currentStreak)-day streak")
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer(minLength: 0)
            MarkTodayButton(entry: entry, compact: true)
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("SpendZero")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(entry.totalSaved.widgetCurrency)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "00E676"))

                Text("Total Saved")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color(hex: "FFD740"))
                    VStack(alignment: .leading) {
                        Text("\(entry.currentStreak)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Day Streak")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: entry.isNoSpendDay ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(entry.isNoSpendDay ? Color(hex: "00E676") : Color(hex: "FF5252"))
                    VStack(alignment: .leading) {
                        Text(entry.isNoSpendDay ? (entry.loggedToday ? "Logged" : "On Track") : "Spent")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Today")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                MarkTodayButton(entry: entry, compact: false)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - One-tap "mark today" button

/// The core loop without opening the app. Disabled once today is logged or has spending.
struct MarkTodayButton: View {
    let entry: SavingsWidgetEntry
    let compact: Bool

    private var isEnabled: Bool { !entry.loggedToday && entry.isNoSpendDay }

    var body: some View {
        Button(intent: MarkNoSpendDayIntent()) {
            if compact {
                Image(systemName: entry.loggedToday ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isEnabled ? Color(hex: "00E676") : .secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: entry.loggedToday ? "checkmark.circle.fill" : "checkmark.seal.fill")
                    Text(entry.loggedToday ? "Logged ✓" : "Mark No-Spend")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isEnabled ? .black : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isEnabled ? Color(hex: "00E676") : Color.secondary.opacity(0.2))
                .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(entry.loggedToday ? "Today already logged" : "Mark today a no-spend day")
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
        .description("Your savings and streak, with a one-tap no-spend day button.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Widget Bundle entry point

@main
struct SpendZeroWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpendZeroSavingsWidget()
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
