import WidgetKit
import SwiftUI

// MARK: - Shared App Group store

private enum WidgetStore {
    static let appGroupID = "group.com.clawdbonzo.SpendZero"
    static func entry() -> SavingsWidgetEntry {
        let d = UserDefaults(suiteName: appGroupID)
        return SavingsWidgetEntry(
            date: Date(),
            totalSaved: d?.double(forKey: "widget.totalSaved") ?? 0,
            currentStreak: d?.integer(forKey: "widget.currentStreak") ?? 0,
            isNoSpendDay: d?.object(forKey: "widget.isNoSpendDay") as? Bool ?? true
        )
    }
}

// MARK: - Widget Timeline Provider

struct SavingsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavingsWidgetEntry {
        SavingsWidgetEntry(date: Date(), totalSaved: 847, currentStreak: 12, isNoSpendDay: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SavingsWidgetEntry) -> Void) {
        // In a gallery/snapshot context, show aspirational sample data.
        if context.isPreview {
            completion(SavingsWidgetEntry(date: Date(), totalSaved: 847, currentStreak: 12, isNoSpendDay: true))
        } else {
            completion(WidgetStore.entry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SavingsWidgetEntry>) -> Void) {
        let entry = WidgetStore.entry()
        // Refresh ~hourly; the app also force-reloads on data changes.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    typealias Entry = SavingsWidgetEntry
}

struct SavingsWidgetEntry: TimelineEntry {
    let date: Date
    let totalSaved: Double
    let currentStreak: Int
    let isNoSpendDay: Bool
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
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
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
                        Text(entry.isNoSpendDay ? "On Track" : "Spent")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Today")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration

struct SpendZeroSavingsWidget: Widget {
    let kind = "SpendZeroSavingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavingsProvider()) { entry in
            SavingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Savings Glance")
        .description("See your total savings and current streak at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
